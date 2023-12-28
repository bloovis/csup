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
    puts "ParentMode.kcommand in object #{object_id}"
  end

  def lcommand
    puts "ParentMode.lcommand in object #{object_id}"
  end
end

class ChildMode < ParentMode
  mode_class(ChildMode)

  def kcommand
    puts "ChildMode.kcommand in object #{object_id}"
  end

  def multicmd
    puts "ChildMode.multicmd"
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
  puts "This is the global quit command."
  exit 0
end

def self.help
  puts "This is the global help command."
end

bm = BufferManager.new
colormap = Colormap.new
Colormap.reset
Colormap.populate_colormap
#pm = ParentMode.new	# This would create a Mode object with a different @@keymaps than cm's
cm = ChildMode.new

Ncurses.start
Ncurses.cbreak
Ncurses.no_echo
Ncurses.keypad(true)	# Handle function keys and arrows
Ncurses.raw
Ncurses.nonl	# don't translate Enter to C-J on input
Ncurses.start_color
Ncurses.use_default_colors

w = Ncurses.stdscr
buf = Buffer.new(w, cm, 80, 25, title: "Phony buffer")
buf.write(0, 0, "This is a yellow string", color: :label_color)
Ncurses.print "\nPress any key to continue: "
ch = Ncurses.getkey
Ncurses.end


bm.focus_on(buf)
puts "Ancestors of ChildMode:"
puts cm.ancestors

global_keymap = Keymap.new do |k|
  k.add(->quit, "Quit", "q")
  k.add(->help, "Help", "h")
end

while true
  print "Command: "
  s = gets || ""
  unless bm.handle_input(s)
    # Either of the following two calls should work.
    #action = BufferManager.resolve_input_with_keymap(s, global_keymap)
    action = bm.resolve_input_with_keymap(s, global_keymap)
    if action
      action.call
    else
      puts "No action for #{s}"
    end
  end
end

end	# module Redwood
