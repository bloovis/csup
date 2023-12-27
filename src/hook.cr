# This HookManager is very different from the one in Sup.  We can't incorporate
# hooks directly into a compiled Crystal binary.  Instead, hooks are individual
# executable programs that take input from stdin, and produce output to stdout.
# The input and output may be either JSON or plain text, depending on the
# particular hook.

require "./singleton"

module Redwood

class HookManager
  class HookPipe
    def initialize(@pipe : Process)
    end

    def send(&)
      yield @pipe.input
      @pipe.input.close
    end

    def receive(&)
      yield @pipe.output
      @pipe.output.close
    end
  end
      
  singleton_class HookManager

  def initialize(@dir : String)
    singleton_pre_init
    @dir = dir
    singleton_post_init
  end

  def run(name : String, &) : Bool
    path = File.join(@dir, name)
    begin
      pipe = Process.new(path,
                         input: Process::Redirect::Pipe,
                         output: Process::Redirect::Pipe)
    rescue IO::Error
      return false
    end
    yield HookPipe.new(pipe)
    pipe.wait
    return true
  end

  def HookManager.run(name : String, &)
    self.instance.run(name) do |pipe|
      yield pipe
    end
  end

end	# HookManager

end	# Redwood
