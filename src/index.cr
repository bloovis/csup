require "json"

module Notmuch
  class ParseError < Exception
  end

  extend self

  def run(args : Array(String),
	  opts : Array(String) = [] of String,
          check_status : Bool = true,
	  check_stderr : Bool = true,
	  filter : String = "",
	  input : String = "")
    if input.size == 0
      io_input = Process::Redirect::Close
    else
      io_input = IO::Memory.new(input)
    end
    io_output = IO::Memory.new
    io_error = IO::Memory.new
    if filter.size > 0
      command = "notmuch " + args.join(" ") + "| " + filter #  \"${@}\"
      args = nil # [] of String
      shell = true
    else
      command = "notmuch"
      shell = false
    end
    puts "Process.run(#{command}, #{args}, shell: #{shell})"
    status = Process.run(command, args, input: io_input, output: io_output,
                         error: io_error, shell: shell)
    puts "Process success: #{status.success?}"
    if (check_status && !status.success?) || (check_stderr && !io_error.empty?)
      stderr_str = io_error.to_s
      raise ParseError.new("Failed to execute #{command}: exitcode=#{status.exit_status}, stderr=#{stderr_str}")
    end
    io_output.to_s
  end

  # low-level

  def lastmod
    run(["count", "--lastmod"]).split.last.to_i
  end

  def poll
    run(["new", "--quiet"], check_stderr: false)
  end

  def count(query : Array(String))
    run(["count"] + query).to_i
  end

  def address(query : Array(String),
	      limit : Int32 = 20)
    run(["address", "--format=text"] + query, filter: "head -n #{limit}")
	.lines.uniq.map {|a| Person.from_address a}
  end

  def search(query : Array(String),
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
    run(args + query).lines
  end

  def show(query : Array(String),
	   body : Bool = false)
    JSON.parse(run(["show", "--format=json", "--body=#{body}"] + query))
  end

  def tag(query : Array(String))
    run(["tag"] + query)
  end

  def tag_batch(query_tags : Array({String, Array(String)}))
    return if query_tags.empty?
    input = query_tags.map do |q, ls|
      "#{ls.map{|l| "+#{l} "}.join} -- #{q}\n"
    end.join
    # @@logger.debug("tag input: #{input}") if @@logger
    run(["tag", "--remove-all", "--batch"], input: input)
  end

  # high-level

  def filenames_from_message_id(mid : String)
    search(["id:#{mid}"], exclude: false, format: "text", output: "files", limit: 1)
  end

  def thread_id_from_message_id(mid : String)
    search(["id:#{mid}"], exclude: false, format: "text", output: "threads", limit: 1)[0]
  end

  def tags_from_message_id(mid : String)
    search(["id:#{mid}"], exclude: false, output: "tags")
  end
end
