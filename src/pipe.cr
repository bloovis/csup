module Redwood

class Pipe
  class PipeError < Exception
  end

  property success = false
  property input_closed = false
  property output_closed = false
  property error_closed = false
  @process : Process?

  def initialize(prog : String, args : Array(String))
    begin
      @process = Process.new(prog,
			     args,
                             input: Process::Redirect::Pipe,
                             output: Process::Redirect::Pipe,
                             error: Process::Redirect::Pipe)
      @success = true
    rescue IO::Error
      @success = false
    end
  end

  def start : Int32	# returns exit status
    yield self
    wait
  end

  def send(&)
    if p = @process
      yield p.input
      p.input.close
    end
    @input_closed = true
  end

  def receive(&)
    if p = @process
      yield p.output
      p.output.close
    end
    @output_closed = true
  end

  def receive_stderr(&)
    if p = @process
      yield p.error
      p.error.close
    end
    @error_closed = true
  end

  def wait : Int32
    if p = @process
      p.input.close unless @input_closed
      p.output.close unless @output_closed
      p.error.close unless @error_closed
      p.wait.exit_status
    else
      -1
    end
  end

  # Used by Notmuch.run.  `input` is an optional string to pass
  # to notmuch's standard input.  The output of notmuch is returned
  # as a string.
  def self.run(prog : String,			# name of program to run
	       args : Array(String),		# arguments
               check_status : Bool = true,	# raise exception if command fails
	       check_stderr : Bool = true,	# raise exception if command wrote to stderr
	       input : String = "") : String	# data to feed to standard input
    pipe = Pipe.new(prog, args)
    unless pipe.success
      raise PipeError.new("Failed to execute #{prog}")
    end

    stdout_str = ""
    stderr_str = ""

    exit_status = pipe.start do |p|
      if input.size != 0
	p.send {|f| f << input}
      end
      p.receive {|f| stdout_str = f.gets_to_end}
      if check_stderr
	p.receive_stderr {|f| stderr_str = f.gets_to_end}
      end
    end

    if (check_status && exit_status != 0) || (check_stderr && !stderr_str.empty?)
      raise PipeError.new("Failed to execute #{prog}: exitcode=#{exit_status}, stderr=#{stderr_str}")
    end
    stdout_str
  end
end	# Pipe

end	# Redwood
