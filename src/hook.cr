# This HookManager is very different from the one in Sup.  We can't incorporate
# hooks directly into a compiled Crystal binary.  Instead, hooks are individual
# executable programs that take input from stdin, and produce output to stdout.
# The input and output may be either JSON or plain text, depending on the
# particular hook.  See test/hook_test.cr for examples of running hooks,
# and see scripts in hooks/ for example of hooks themselves.

require "./singleton"

module Redwood

class HookManager
  singleton_class

  property dir : String

  def initialize(@dir : String)
    singleton_pre_init
    @dir = dir
    singleton_post_init
  end

  def self.run(name : String, &) : Bool
    path = File.join(self.instance.dir, name)
    begin
      pipe = Pipe.new(path, [] of String)
      exit_status = pipe.start {|p| yield p}
      return exit_status == 0
    rescue IO::Error
      return false
    end
  end

end	# HookManager

end	# Redwood
