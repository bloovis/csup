require "../src/keymap"
require "../src/buffer"
require "../src/mode"
require "../src/supcurses"

module Redwood

class ParentMode < Mode
  mode_class(ParentMode)

  def initialize
    super
    puts "Initializing ParentMode object #{object_id}"
    register_keymap(CLASSNAME) do |k|
      k.add(-> kcommand, "ParentMode k command", "k")
      k.add(-> lcommand, "ParentMode l command", "l")
    end
  end

  def kcommand
    BufferManager.say "ParentMode.kcommand in object #{object_id}"
  end

  def lcommand
    BufferManager.say "ParentMode.lcommand in object #{object_id}"
  end
end

class ChildMode < ParentMode
  mode_class(ChildMode)

  def kcommand
    BufferManager.say "ChildMode.kcommand in object #{object_id}"
  end

  def multicmd
    BufferManager.say "ChildMode.multicmd"
  end

  def initialize
    super
    puts "Initializing ChildMode object #{object_id}"
    register_keymap(CLASSNAME) do |k|
      k.add(-> kcommand, "ChildMode k command", "k")
      k.add_multi("ChildMode m commands", "m") do |kk|
        kk.add(-> multicmd, "ChildMode n command", "n")
      end
    end
  end

end
    
def self.quit
  BufferManager.say "This is the global quit command."
  Ncurses.end
  exit 0
end

def self.help
  BufferManager.say "This is the global help command."
end

bm = BufferManager.new
colormap = Colormap.new
Colormap.reset
Colormap.populate_colormap
#pm = ParentMode.new	# This would create a Mode object with a different @@keymaps than cm's
cm = ChildMode.new
puts "Ancestors of ChildMode:"
puts cm.ancestors

start_cursing

w = Ncurses.stdscr
buf = bm.spawn("Child Mode", cm, 80, 25)
#buf = Buffer.new(w, cm, 80, 25, title: "Phony buffer")
bm.raise_to_front(buf)
bm.say("Testing BufferManager.say")
say_id = 0
bm.say("Testing BufferManager.say with a block") {|id| say_id = id}
bm.say("Testing BufferManager.say with reused id #{say_id}", id: say_id)
buf.write(20, 0, "This is a yellow string", color: :label_color)
buf.draw_status("status line")
#Ncurses.print "\nPress any key to continue:\n"
#ch = Ncurses.getkey
bm.ask_getch("Press any key to continue:")

global_keymap = Keymap.new do |k|
  k.add(->quit, "Quit", ["q", "C-q"])
  k.add(->help, "Help", "h")
end

while true
  ch = bm.ask_getch("Command: ")
  unless bm.handle_input(ch)
    # Either of the following two calls should work.
    #action = BufferManager.resolve_input_with_keymap(ch, global_keymap)
    action = bm.resolve_input_with_keymap(ch, global_keymap)
    if action
      action.call
    else
      BufferManager.say "No action for #{ch}"
    end
  end
end

stop_cursing

end	# module Redwood
