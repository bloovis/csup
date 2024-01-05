require "json"
require "./pipe"

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

  def address(query : String,
	      limit : Int32 = 20)
    Pipe.run("notmuch", ["address", "--format=text", query], filter: "head -n #{limit}")
	.lines.uniq.map {|a| Person.from_address a}
  end

  def search(query : String,
	     format : String = "text",
	     exclude : Bool = true,
	     output : String = "threads",
	     offset : (Int32 | Nil) = nil,
	     limit : (Int32 | Nil) = nil)
    # search threads, return thread ids
    args = ["search", "--format=#{format}", "--output=#{output}"]
    args << "--offset=#{offset}" if offset
    args << "--limit=#{limit}" if limit
    args << "--exclude=false" unless exclude
    args << query
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

  def tag_batch(query_tags : Array({String, Array(String)}))
    return if query_tags.empty?
    input = query_tags.map do |q, ls|
      "#{ls.map{|l| "+#{l} "}.join} -- #{q}\n"
    end.join
    # @@logger.debug("tag input: #{input}") if @@logger
    Pipe.run("notmuch", ["tag", "--remove-all", "--batch"], input: input)
  end

  # high-level

  def filenames_from_message_id(mid : String)
    search("id:#{mid}", exclude: false, format: "text", output: "files", limit: 1)
  end

  def thread_id_from_message_id(mid : String)
    search("id:#{mid}", exclude: false, format: "text", output: "threads", limit: 1)[0]
  end

  def tags_from_message_id(mid : String)
    search("id:#{mid}", exclude: false, output: "tags")
  end

  def load_contacts(email_addresses : Array(String), limit : Int32 = 20)
  end

end	# module Notmuch

end	# module Redwood
