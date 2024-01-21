require "json"
require "./pipe"
require "./hook"
require "./contact"
require "./account"

module Redwood

module Notmuch
  class ParseError < Exception
  end

  extend self

  # low-level

  def lastmod
    Pipe.run("notmuch", ["count", "--lastmod"]).split.last.to_i
  end

  def poll
    Pipe.run("notmuch", ["new", "--quiet"], check_stderr: false)
  end

  def count(query : String)
    Pipe.run("notmuch", ["count", query]).to_i
  end

  def search(query : String,
	     format : String = "text",
	     exclude : Bool = true,
	     output : String = "threads",
	     offset : (Int32 | Nil) = nil,
	     limit : (Int32 | Nil) = nil) : Array(String)
    # search threads, return thread ids
    args = ["search", "--format=#{format}", "--output=#{output}"]
    args << "--offset=#{offset}" if offset
    args << "--limit=#{limit}" if limit
    args << "--exclude=false" unless exclude
    args << query
    #STDERR.puts "notmuch #{args}"
    Pipe.run("notmuch", args).lines
  end

  def show(query : String,
	   body : Bool = false,
	   html : Bool = false) : JSON::Any
    JSON.parse(Pipe.run("notmuch",
			["show", "--format=json", "--include-html=#{html}",
                         "--body=#{body}", query]))
  end

  def tag(query : String)
    Pipe.run("notmuch", ["tag", query])
  end

  # Each entry in query_tags is a tuple containing:
  # - a query string in the form "id:messageid"
  # - an array of tags to apply to that message
  def tag_batch(query_tags : Array({String, Array(String)}))
    return if query_tags.empty?
    input = query_tags.map do |q, ls|
      "#{ls.map{|l| "+#{l} "}.join} -- #{q}\n"
    end.join
    # @@logger.debug("tag input: #{input}") if @@logger
    #STDERR.puts "notmuch tag --remove-all --batch, input:\n#{input}\n"
    Pipe.run("notmuch", ["tag", "--remove-all", "--batch"], input: input)
  end

  def save_part(msgid : String, partid : Int32, filename : String) : Bool
    if File.exists?(filename)
      return false
    end
    puts "About to run notmuch show --part=#{partid} id:#{msgid}"
    pipe = Pipe.new("notmuch", ["show", "--part=#{partid}", "id:#{msgid}"])
    pipe.start do |p|
      p.receive do |output|
        File.open(filename, "w") do |f|
	  IO.copy(output, f)
	end
      end
    end
    return true
  end

  def view_part(msgid : String, partid : Int32, content_type : String) : Bool
    puts "About to run notmuch show --part=#{partid} id:#{msgid}"
    pipe = Pipe.new("notmuch", ["show", "--part=#{partid}", "id:#{msgid}"])
    success = false
    pipe.start do |p|
      p.receive do |output|
        success = HookManager.run("mime-view") do |hook|
	  hook.send do |f|
	    f.puts content_type
	    IO.copy(output, f)
	  end
	end
      end
    end
    return success
  end

  # high-level

  def filenames_from_message_id(mid : String)
    search("id:#{mid}", exclude: false, format: "text", output: "files", limit: 1)
  end

  # Return thread id for the given message id, or empty string if not found.
  def thread_id_from_message_id(mid : String) : String
    lines = search("id:#{mid}", exclude: false, format: "text", output: "threads", limit: 1)
    if lines.size > 0
      return lines[0]
    else
      return ""
    end
  end

  def tags_from_message_id(mid : String)
    search("id:#{mid}", exclude: false, output: "tags")
  end

  def save_thread(t : MsgThread)
{% if false %}
    tags = t.labels.to_a.join(",")
    if m = t.msg
      mid = m.id
    else
      mid = "<unknown>"
    end
    STDERR.puts "Notmuch.save_thread: saving thread for message #{mid}, tags #{tags}"
{% end %}
    Message.sync_back_labels t.messages
  end

  def load_contacts(email_addresses : Array(String), limit : Int32 = 20)
  end

  # Translate a query string from the user into one that can
  # be passed to notmuch search.  Translations include:
  # - to:/from:person -> look up person's email address contacts list
  # - label:/is:/has: -> tag:
  # - filename: -> attachment:
  # - filetype: -> mimetype:
  # - before|on|in|during|after: -> date:?..?

  def translate_query(s : String) : String
    subs = ""

    begin
      subs = SearchManager.expand s
    rescue e : SearchManager::ExpansionError
      raise ParseError.new(e.message)
    end
    subs = subs.gsub(/\b(to|from):(\S+)\b/) do
      field, value = $1, $2
      p = ContactManager.contact_for(value)
      if p
        "#{field}:#{p.email}"
      elsif value == "me"
        "(" + AccountManager.user_emails.map { |e| "#{field}:#{e}" }.join(" OR ") + ")"
      else
        "#{field}:#{value}"
      end
    end

    ## gmail style "is" operator
    subs = subs.gsub(/\b(is|has):(\S+)\b/) do
      field, label = $1, $2
      case label
      when "read"
        "(not tag:unread)"
      when "spam"
        "tag:spam"
      when "deleted"
        "tag:deleted"
      else
        "tag:#{$2}"
      end
    end

    ## labels are stored lower-case in the index
    subs = subs.gsub(/\blabel:([\w-]+)\b/) do
      label = $1
      "tag:#{label.downcase}"
    end
    subs = subs.gsub(/\B-(tag|label):([\w-]+)/) do
      label = $2
      "(not tag:#{label.downcase})"
    end

    ## gmail style attachments "filename" and "filetype" searches
    subs = subs.gsub(/\b(filename|filetype):(\((.+?)\)\B|(\S+)\b)/) do
      field, name = $1, ($3? || $2)
      case field
      when "filename"
        #debug "filename: translated #{field}:#{name} to attachment:\"#{name.downcase}\""
        "attachment:\"#{name.downcase}\""
      when "filetype"
        #debug "filetype: translated #{field}:#{name} to mimetype:#{name.downcase}"
        "mimetype:#{name.downcase}"
      end
    end

    subs = subs.gsub(/\b(before|on|in|during|after):(\((.+?)\)\B|(\S+)\b)/) do
      field, datestr = $1, ($3? || $2)
      datestr = datestr.gsub(" ","_")       # translate spaces to underscores
      case field
      when "after"
	"date:#{datestr}.."
      when "before"
	"date:..#{datestr}"
      else
	"date:#{datestr}"
      end
    end

    #debug "translated query: #{subs.inspect}"
    return subs
  end

end	# module Notmuch

end	# module Redwood
