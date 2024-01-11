# Parse the result of: notmuch show --body=true --format=json --include-html thread:#{threadid}
# where <threadid> is specified on the command line.  If the -c option
# is also specified, content parts are also displayed.

# Other useful notmuch commands for the future:
#
# Obtain readable version of HTML attachment:
#   notmuch show --part=#{N} id:#{msgid} | w3m -T text/html
# Save an attachment to a file:
#   notmuch show --part=#{N} id:#{msgid} >filename

require "json"
require "./index"

module Redwood

class Content
  property id : Int32
  property content_type : String
  property filename : String
  property content : String

  def initialize(@id, @content_type, @filename, @content)
  end
end

# A message is actually a tree of messages: it can have multiple children.
class Message
  alias ContentParts = Hash(Int32, Content)
  alias Headers = Hash(String, String)

  property id : String = ""
  property parent : Message | Nil
  property children : Array(Message)
  property headers : Headers
  property tags : Set(String)
  property content : ContentParts	# content parts indexed by a numeric ID
  property timestamp : Int64
  property filename : String
  property date_relative : String
  property thread : MsgThread?		# containing thread

  # If a JSON result from "notmuch show" is provided in `data`, parse it
  # to fill in the message fields.  Otherwise use some empty default values, and
  # use `data` as the message ID.
  def initialize(data = nil)
    @parent = nil
    @children = Array(Message).new
    @headers = Headers.new
    @tags = Set(String).new
    @content = ContentParts.new
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
  end

  def add_child(child : Message)
    @children << child
    child.parent = self
  end

  def add_header(name, value)
    @headers[name] = value
  end

  def add_tag(name : String)
    @tags.add(name)
  end

  def add_content(id : Int32, ctype : String, filename : String, s : String)
    content[id] = Content.new(id, ctype, filename, s)
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
    puts "#{prefix}  tags: #{@tags.to_a.join(",")}"
    puts "#{prefix}  date_relative: #{@date_relative}"

    puts "#{prefix}  headers:"
    headers.each do |k,v|
      puts "#{prefix}    #{k} = #{v}"
    end

    content.each do |id, c|
      colon = (print_content ? ":" : "")
      puts "#{prefix}  Content ID #{c.id}, content type #{c.content_type}, filename '#{c.filename}'#{colon}\n"
      if c.content == ""
	puts "#{prefix}  Content missing!"
      elsif print_content
        puts c.content
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

  # Functions for parsing messages.

  def parse_part(p : JSON::Any)
    part = p.as_h?
    if part
      #puts "part: #{part.inspect}"
      id =      part["id"].as_i
      ctype =   part["content-type"].as_s
      if part.has_key?("filename")
	filename = part["filename"].as_s
      else
	filename = ""
      end
      #puts "about to get content for part #{id}, ctype #{ctype}"
      if part.has_key?("content")
	content = part["content"].as_s?
	if content
	  #puts "Adding content for part #{id}, content:\n---\n#{content}\n---\n"
	  add_content(id, ctype, filename, content)
	else
	  content = part["content"].as_a?
	  if content
	    content.each do |c|
	      parse_part(c)
	    end
	  end
	end
      else
	add_content(id, ctype, filename, "")	# attachment with no content in JSON
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

class MsgThread
  property msg : Message?
  property next : MsgThread?
  property prev : MsgThread?

  def initialize(json : JSON::Any)
    #puts "MsgThread  #{json}"
    msglist = json.as_a	# There always seems to be only one message in the array
    m = Message.new(msglist[0])
    @msg = m
    m.walktree {|msg, i| msg.thread = self}
  end

  def print(print_content = false)
    if m = @msg
      puts "Thread object id #{self.object_id}, prev #{@prev.object_id}, next #{@next.object_id}"
      m.print(level: 0, print_content: print_content)
    else
      puts "Thread is empty!"
    end
  end

  def walktree(&b : Message, Int32 -> _)
    if m = @msg
      m.walktree do |msg, depth|
        b.call msg, depth
      end
    end
  end

end	# MsgThread

class ThreadList
  property threads = Array(MsgThread).new
  property query = ""

  def initialize(query : String, offset : Int32, limit : Int32)
    puts "ThreadList: query #{query}"
    if query
      run_notmuch_show(query, offset: offset, limit: limit)
    end
  end

  # Run 'notmuch search' and 'notmuch show' to obtain the threads for the
  # specified query string.
  def run_notmuch_show(query : String, offset : Int32? = nil, limit : Int32? = nil)
    puts "run_notmuch_show: query #{query}"
    @query = query

    # First, get the list of threads matching the query.
    lines = Notmuch.search(query, offset: offset, limit: limit)
    if lines.size == 0
      puts "run_notmuch_show: query '#{query}' produced no results"
      return
    end

    # Construct a show query from the list of threads and obtain
    # the JSON output.
    show_query = lines.join(" or ")
    puts "run_notmuch_show: query #{query}"
    json = Notmuch.show(show_query, body: true, html: true)
    parse_json(json)
  end

  def parse_json(json : JSON::Any)
    #puts "parse_json #{json}"
    results = json.as_a?
    if results
      puts "results is an array"
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
