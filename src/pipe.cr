require "./shellwords"

module Redwood

module Pipe
  class PipeError < Exception
  end

  extend self

  def run(prog : String,		# name of program to run
	  args : Array(String),		# arguments
          check_status : Bool = true,	# raise exception if command fails
	  check_stderr : Bool = true,	# raise exception if command wrote to stderr
	  filter : String = "",		# command to filter output
	  input : String = "")		# data to feed to standard input
    if input.size == 0
      io_input = Process::Redirect::Close
    else
      io_input = IO::Memory.new(input)
    end
    io_output = IO::Memory.new
    io_error = IO::Memory.new
    if filter.size > 0
      command = prog +
		" " +
		args.map{|a| Shellwords.escape(a)}.join(" ") + "| " + filter
      args = nil # [] of String
      shell = true
    else
      command = prog
      shell = false
    end
    #puts "Process.run: #{command}, #{args}, shell: #{shell}, input:\n---\n#{input}---\n"
    status = Process.run(command, args, input: io_input, output: io_output,
                         error: io_error, shell: shell)
    #puts "Process success: #{status.success?}"
    if (check_status && !status.success?) || (check_stderr && !io_error.empty?)
      stderr_str = io_error.to_s
      raise PipeError.new("Failed to execute #{command}: exitcode=#{status.exit_status}, stderr=#{stderr_str}")
    end
    io_output.to_s
  end

end	# Pipe

end	# Redwood
