# Create message thread list by parsing the result of:
#  notmuch search --format=text "query"
#  notmuch show --body=true --format=json --include-html --body=true "thread:ID1 or thread:ID2 or ..."
# where the result of `notmuch search` is passed to `notmuch show`.

require "json"
require "./notmuch"
require "./person"
require "./time"
require "./chunks"

module Redwood

# A message is actually a tree of messages: it can have multiple children.
class Message

  class Part
    property id : Int32
    property content_type : String
    property filename : String
    property content : String
    property content_size : Int32

    def initialize(@id, @content_type, @filename, @content, @content_size)
    end
  end

  QUOTE_PATTERN = /^\s{0,4}[>|\}]/
  BLOCK_QUOTE_PATTERN = /^-----\s*Original Message\s*----+$/
  SIG_PATTERN = /(^(- )*-- ?$)|(^\s*----------+\s*$)|(^\s*_________+\s*$)|(^\s*--~--~-)|(^\s*--\+\+\*\*==)/
  MAX_SIG_DISTANCE = 15 # lines from the end
  SNIPPET_LEN = 80

  alias Parts =  Array(Part)
  alias Headers = Hash(String, String)

  property id : String = ""
  property parent : Message | Nil
  property children : Array(Message)
  property headers : Headers
  property labels : Set(String)
  property parts : Parts	# parts indexed by a numeric ID
  property timestamp : Int64
  property filename : String
  property date_relative : String
  property thread : MsgThread?		# containing thread
  property from : Person
  property to : Array(Person)
  property cc : Array(Person)
  property bcc : Array(Person)
  property subj = "<no subject>"
  property date : Time
  property chunks = Array(Chunk).new
  property have_snippet = false
  property snippet = ""
  property dirty_labels = false

  # If a JSON result from "notmuch show" is provided in `data`, parse it
  # to fill in the message fields.  Otherwise use some empty default values, and
  # use `data` as the message ID.
  def initialize(data = nil)
    @parent = nil
    @children = Array(Message).new
    @headers = Headers.new
    @labels = Set(String).new
    @parts = Parts.new
    @timestamp = 0
    @filename = ""
    @date_relative = ""
    if data.nil?
      @id = "<dummy>"
    elsif data.is_a?(String)
      @id = data
    else
      parse_message(data)
    end

    # Fill in some properties for Sup compatibility.
    if @headers.has_key?("From")
      @from = Person.from_address(headers["From"])
    else
      @from = Person.new("nobody", "nobody@example.com")
    end
    if @headers.has_key?("Subject")
      @subj = @headers["Subject"]
    else
      @subj = "<no subject>"
    end
    @to = Person.from_address_list(@headers["To"]?)
    @cc = Person.from_address_list(@headers["Cc"]?)
    @bcc = Person.from_address_list(@headers["Bcc"]?)
    @date = Time.unix(@timestamp)

    walktree do |msg, i|
      msg.find_chunks
    end
  end

  def dirty_labels?; @dirty_labels end

  def add_child(child : Message)
    @children << child
    child.parent = self
  end

  def add_header(name, value)
    @headers[name] = value
  end

  def add_tag(name : String)
    @labels.add(name)
  end

  # For Sup compatibility
  def clear_dirty_labels
    @dirty_labels = false
  end

  def has_label?(s : Symbol | String)
    @labels.includes?(s.to_s)
  end

  def add_label(l : Symbol | String)
    l = l.to_s
    return if @labels.includes? l
    @labels.add(l)
    @dirty_labels = true
  end

  def remove_label(l : Symbol | String)
    l = l.to_s
    return unless @labels.includes? l
    @labels.delete l
    @dirty_labels = true
  end

  def is_draft?; has_label?(:draft) end

  def sync_back_labels
    Message.sync_back_labels [self]
  end

  def self.sync_back_labels(messages : Array(Message))
    dirtymessages = messages.select{|m| m && m.dirty_labels?}
    Notmuch.tag_batch(dirtymessages.map{|m| {"id:#{m.id}", m.labels.to_a}})
    dirtymessages.each(&.clear_dirty_labels)
  end

  # Code for constructing parts
  def add_part(id : Int32, ctype : String, filename : String, s : String, content_size : Int32)
    if filename == ""
      newname = "csup-attachment-#{Time.now.to_i}-#{rand 10000}"
      if ctype =~ /text\/html/
	filename = newname + "." + "html"
      elsif ctype =~ /image\/(.*)/
	filename = newname + "." + $1
      else
	filename = newname
      end
    end
    @parts << Part.new(id, ctype, filename, s, content_size)
  end

  def find_part(&b : Part -> Bool) : Part?
    @parts.each do |p|
      if b.call(p)
	return p
      end
    end
    return nil
  end

  def print(level = 0, print_content = false)
    prefix = "  " * level
    puts "#{prefix}Message:"
    puts "#{prefix}  id: #{@id}"
    puts "#{prefix}  filename: #{@filename}"
    parent = @parent
    if parent
      puts "#{prefix}  parent id: #{parent.id}"
    end

    puts "#{prefix}  timestamp: #{@timestamp} (#{Time.unix(@timestamp)})"
    puts "#{prefix}  tags: #{@labels.to_a.join(",")}"
    puts "#{prefix}  date_relative: #{@date_relative}"

    puts "#{prefix}  headers:"
    headers.each do |k,v|
      puts "#{prefix}    #{k} = #{v}"
    end

    @parts.each do |p|
      colon = (print_content ? ":" : "")
      puts "#{prefix}  Part ID #{p.id}, content type #{p.content_type}, filename '#{p.filename}'#{colon}\n"
      if p.content == ""
	puts "#{prefix}  Content missing!"
      elsif print_content
        puts p.content
      end
    end

    if @children.size > 0
      puts "#{prefix}  Children:"
      @children.each do |child|
	child.print(level + 2, print_content)
      end
    end
  end

  # Walk the the tree of messages, passing each message and its depth
  # to the block.
  private def do_walk(msg : Message, depth : Int32, &b : Message, Int32 -> _)
    b.call msg, depth
    msg.children.each do |child|
      do_walk(child, depth + 1, &b)
    end
  end

  def walktree(&b : Message, Int32 -> _)
   do_walk(self, 0) {|msg, depth| b.call msg, depth}
  end

  def append_chunk(chunks : Array(Chunk), lines : Array(String), type : Symbol)
    #STDERR.puts "append_chunk: type #{type}, #lines = #{lines.size}"
    return if lines.empty?
    chunk = case type
            when :text
              TextChunk.new(lines)
            when :quote, :block_quote
              QuoteChunk.new(lines)
            when :sig
              SignatureChunk.new(lines)
            else
              raise "unknown chunk type: #{type}"
            end
    if chunk
      chunks << chunk
    end
  end

  ## parse the lines of text into chunk objects.  the heuristics here
  ## need tweaking in some nice manner. TODO: move these heuristics
  ## into the classes themselves.
  def text_to_chunks(lines : Array(String), encrypted = false) : Array(Chunk)
    state = :text # one of :text, :quote, or :sig
    chunks = [] of Chunk
    chunk_lines = [] of String
    nextline_index = -1

    lines.each_with_index do |line, i|
      #STDERR.puts "text_to_chunks: line #{i} = '#{line.chomp}'"
      if i >= nextline_index
        # look for next nonblank line only when needed to avoid O(n²)
        # behavior on sequences of blank lines
        if nextline_index = lines[(i+1)..-1].index { |l| l !~ /^\s*$/ } # skip blank lines
          nextline_index += i + 1
          nextline = lines[nextline_index]
        else
          nextline_index = lines.length
          nextline = nil
        end
      end

      case state
      when :text
        newstate = nil

        ## the following /:$/ followed by /\w/ is an attempt to detect the
        ## start of a quote. this is split into two regexen because the
        ## original regex /\w.*:$/ had very poor behavior on long lines
        ## like ":a:a:a:a:a" that occurred in certain emails.
        if line =~ QUOTE_PATTERN || (line =~ /:$/ && line =~ /\w/ && nextline =~ QUOTE_PATTERN)
	  #STDERR.puts "in quote, line = '#{line}', nextline = '#{nextline}'"
          newstate = :quote
        elsif line =~ SIG_PATTERN && (lines.length - i) < MAX_SIG_DISTANCE && !lines[(i+1)..-1].index { |l| l =~ /^-- $/ }
          newstate = :sig
        elsif line =~ BLOCK_QUOTE_PATTERN
          newstate = :block_quote
        end

        if newstate
          append_chunk(chunks, chunk_lines, state)
          chunk_lines = [line]
          state = newstate
        else
          chunk_lines << line
        end

      when :quote
        newstate = nil

        if line =~ QUOTE_PATTERN || (line =~ /^\s*$/ && nextline =~ QUOTE_PATTERN)
          chunk_lines << line
        elsif line =~ SIG_PATTERN && (lines.length - i) < MAX_SIG_DISTANCE
          newstate = :sig
        else
          newstate = :text
        end

        if newstate
          append_chunk(chunks, chunk_lines, state)
          chunk_lines = [line]
          state = newstate
        end

      when :block_quote, :sig
        chunk_lines << line
      end

      if !@have_snippet && state == :text && (@snippet.nil? || @snippet.length < SNIPPET_LEN) && line !~ /[=\*#_-]{3,}/ && line !~ /^\s*$/
        @snippet ||= ""
        @snippet += " " unless @snippet.empty?
        @snippet += line.gsub(/^\s+/, "").gsub(/[\r\n]/, "").gsub(/\s+/, " ")
        oldlen = @snippet.length
        @snippet = @snippet[0 ... SNIPPET_LEN].chomp
        @snippet += "..." if @snippet.length < oldlen
        @snippet_contains_encrypted_content = true if encrypted
      end
    end

    ## final object
    append_chunk(chunks, chunk_lines, state)
    chunks
  end

  # Find all chunks for this message.
  def find_chunks
    @chunks = [] of Chunk
    found_plain = false
    @parts.each do |p|
      if p.content_type == "text/plain" && p.content_size > 0
	found_plain = true
	lines = p.content.lines
	@chunks = @chunks + text_to_chunks(lines)
      else
        result = ""
	# If this is a non-empty part HTML part, and we haven't
	# seen a plain text part yet, decode it and treat it as it were
	# plain text attachment.
	if p.content_type == "text/html" && p.content_size > 0 && !found_plain
	  success = HookManager.run("mime-decode") do |pipe|
	    pipe.send do |f|
	      f.puts(p.content_type)
	      f << p.content
	    end
	    pipe.receive do |f|
	      result = f.gets_to_end
	    end
	  end
	end
	if result.size > 0
	  lines = result.lines
	  @chunks = @chunks + text_to_chunks(lines)
	else
	  @chunks << AttachmentChunk.new(p, self)
	end
      end
    end
  end

  # Functions for parsing messages.

  def parse_part(p : JSON::Any)
    part = p.as_h?
    if part
      #puts "part: #{part.inspect}"
      id =      part["id"].as_i
      ctype =   part["content-type"].as_s.downcase
      if part.has_key?("filename")
	filename = part["filename"].as_s
      else
	filename = ""
      end
      if part.has_key?("content-length")
	content_length = part["content-length"].as_i
      else
	content_length = 0
      end
      #puts "about to get content for part #{id}, ctype #{ctype}"
      if part.has_key?("content")
	content = part["content"].as_s?
	if content
	  #puts "Adding content for part #{id}, content:\n---\n#{content}\n---\n"
	  add_part(id, ctype, filename, content, content.size)
	else
	  content = part["content"].as_a?
	  if content
	    content.each do |c|
	      parse_part(c)
	    end
	  end
	end
      else
	add_part(id, ctype, filename, "", content_length)	# attachment with no content in JSON
      end
    end
  end

  def single_message(msg_info : Hash(String, JSON::Any))
    @id = msg_info["id"].as_s

    tags = msg_info["tags"].as_a?
    if tags
      tags.each { |tag| add_tag(tag.as_s)}
    end

    if msg_info.has_key?("timestamp")
      timestamp = msg_info["timestamp"].as_i64?
      if timestamp
	@timestamp = timestamp
      end
    end

    headers = msg_info["headers"].as_h?
    if headers
      headers.each do |k, v|
	key = k
	if key
	  value = v.as_s?
	  if value
	    add_header(key, value)
	  end
	end
      end
    end

    if msg_info.has_key?("body")
      body = msg_info["body"].as_a?
      if body
	body.each do |p|
	  parse_part(p)
	end
      end
    end

    if msg_info.has_key?("filename")
      filenamelist = msg_info["filename"].as_a?
      if filenamelist
	@filename = filenamelist[0].as_s
      end
    end

    if msg_info.has_key?("date_relative")
      date = msg_info["date_relative"].as_s?
      if date
	@date_relative = date
      end
    end
  end

  def parse_message(json : JSON::Any)
    #puts "parse_message #{json}"
    msgarray = json.as_a
    msg_info = msgarray[0].as_h?
    if msg_info
      single_message msg_info
    else
      @id = "<null>"
    end
    children = msgarray[1].as_a?
    if children
      children.each do |child|
	c = Message.new(child)
	add_child(c)
      end
    end
  end

end	# Message

alias ThreadEach = Tuple(Message, Int32, Message?)	# thread, depth, parent

class MsgThread
  include Enumerable(ThreadEach)

  property msg : Message?
  property next : MsgThread?
  property prev : MsgThread?
  property size = 0
  property subj = "<no subject>"

  def initialize(json : JSON::Any)
    #puts "MsgThread  #{json}"
    msglist = json.as_a	# There always seems to be only one message in the array
    m = Message.new(msglist[0])
    @msg = m
    @size = 0
    m.walktree do |msg, depth|
      msg.thread = self
      @size += 1
    end
    @dirty_labels = false
    @subj = m.subj
  end

  def to_s : String	# for creating debug messages
    if m = @msg
      mid = m.id
    else
      mid = "<unknown>"
    end
    "thread #{self.object_id}, msg id:#{mid}"
  end

  def messages : Array(Message)
    a = Array(Message).new
    if m = @msg
      m.walktree { |msg, depth| a << msg }
    end
    return a
  end

  def apply_label(t); each { |m, d, p| m && m.add_label(t) }; end
  def remove_label(t); each { |m, d, p| m && m.remove_label(t) }; end

  def toggle_label(label)
    if has_label? label
      remove_label label
      false
    else
      apply_label label
      true
    end
  end

  def has_label?(t); any? { |m, d, p| m && m.has_label?(t) }; end

  def labels
    l = Set(String).new
    each {|m, d, p| l = l + m.labels}
    return l
  end

  def date
    if m = @msg
      Time.unix(m.timestamp)
    else
      Time.local
    end
  end

  def snippet : String
    with_snippets = Array(Message).new
    each do |m, d, p|
      if m && m.snippet != ""
	with_snippets << m
      end
    end
    first_unread = with_snippets.select { |m| m.has_label?(:unread) }.sort_by(&.date).first?
    return first_unread.snippet if first_unread
    last_read = with_snippets.sort_by(&.date).last?
    return last_read.snippet if last_read
    ""
  end

  def first : Message?
    @msg
  end

  def print(print_content = false)
    if m = @msg
      puts "Thread object id #{self.object_id}, prev #{@prev.object_id}, next #{@next.object_id}"
      m.print(level: 0, print_content: print_content)
    else
      puts "Thread is empty!"
    end
  end

  # This allows MsgThread.map to be used.  We can't yield inside
  # the walktree block, so we have to save the results of walktree, then
  # yield them afterwards.
  def each
    if m = @msg
      results = Array(ThreadEach).new
      m.walktree do |msg, depth|
        results << {msg, depth, msg.parent}
      end
      results.each {|r| yield r}
    end
  end

  def authors : Array(Person)
    map { |m, d, p| m.from if m }.compact.uniq
  end

  def participants : Array(Person)
    map { |m, d, p| [m.from] + m.to + m.cc + m.bcc if m }.flatten.compact.uniq
  end

end	# MsgThread

class ThreadList
  property threads = Array(MsgThread).new
  property query = ""

  def initialize(@query, offset : Int32, limit : Int32)
    #system("echo ThreadList.new: query #{@query}, offset #{offset}, limit #{limit} >>/tmp/csup.log")
    if query
      run_notmuch_show(@query, offset: offset, limit: limit)
    end
  end

  # Run 'notmuch search' and 'notmuch show' to obtain the threads for the
  # specified query string.
  def run_notmuch_show(query : String, offset : Int32? = nil, limit : Int32? = nil)
    #puts "run_notmuch_show: query #{query}, caller #{caller[0]}"
    #system("echo run_notmuch_show query #{query}, offset #{offset}, limit #{limit} >>/tmp/csup.log")
    @query = query

    # First, get the list of threads matching the query.
    lines = Notmuch.search(query, offset: offset, limit: limit)
    if lines.size == 0
      #puts "run_notmuch_show: query '#{query}' produced no results"
      return
    end

    # Construct a show query from the list of threads and obtain
    # the JSON output.
    show_query = lines.join(" or ")
    #puts "run_notmuch_show: query #{query}"
    json = Notmuch.show(show_query, body: true, html: true)
    parse_json(json)
  end

  def parse_json(json : JSON::Any)
    #puts "parse_json #{json}"
    results = json.as_a?
    if results
      #puts "results is an array"
      prev_thread = nil
      results.each do |result|
        thread = MsgThread.new(result)
	thread.prev = prev_thread
	if prev_thread
	  prev_thread.next = thread
	end
	prev_thread = thread
	threads << thread
      end
    else
      puts "results is a #{json.class.name}, expected array"
    end
  end

  def find_thread(other : MsgThread) : MsgThread?
    return unless m = other.msg
    mid = m.id
    threads.each do |t|
      t.messages.each do |m|
        if m.id == mid
	  return t
	end
      end
    end
    return nil
  end

  def print(print_content = false)
    puts "ThreadList:"
    @threads.each_with_index do |thread, i|
      puts "----"
      puts "Thread #{i}:"
      thread.print(print_content: print_content)
    end
  end

end	# ThreadList

end	# Redwood
