require "../src/keymap"
require "../src/buffer"
require "../src/mode"
require "../src/supcurses"

module Redwood

class ParentMode < Mode
  def initialize
    puts "Initializing ParentMode object #{object_id}"
    register_keymap("ParentMode") do |k|
      k.add(-> kcommand, "ParentMode k command", "k")
      k.add(-> lcommand, "ParentMode l command", "l")
    end
  end

  def ancestors
    #puts "ParentMode.ancestors"
    ["ParentMode"] + super
  end

  def kcommand
    puts "ParentMode.kcommand in object #{object_id}"
  end

  def lcommand
    puts "ParentMode.lcommand in object #{object_id}"
  end
end

class ChildMode < ParentMode
  def ancestors
    #puts "ChildMode.ancestors"
    ["ChildMode"] + super
  end

  def kcommand
    puts "ChildMode.kcommand in object #{object_id}"
  end

  def multicmd
    puts "ChildMode.multicmd"
  end

  def initialize
    super
    puts "Initializing ChildMode object #{object_id}"
    register_keymap("ChildMode") do |k|
      k.add(-> kcommand, "ChildMode k command", "k")
      k.add_multi("ChildMode m commands", "m") do |kk|
        kk.add(-> multicmd, "ChildMode n command", "n")
      end
    end
  end

end
    
def self.quit
  puts "Quitting!"
  exit 0
end

def self.help
  puts "This is the help command"
end

bm = BufferManager.new
#pm = ParentMode.new	# This would create a Mode object with a different @@keymaps than cm's
cm = ChildMode.new

Ncurses.start
w = Ncurses.stdscr
Ncurses.end

buf = Buffer.new(w, cm, 80, 25, {:title => "Phony buffer"})

bm.focus_on(buf)
puts "Ancestors of ChildMode:"
puts cm.ancestors
while true
  print "Command: "
  s = gets || ""
  bm.handle_input s
  break if s == "q"
end

global_keymap = Keymap.new do |k|
  k.add(->quit, "Quit", "q")
  k.add(->help, "Help", "h")
end

while true
  print "Global Command: "
  s = gets || ""
  # Either of the following two calls should work.
  #action = BufferManager.resolve_input_with_keymap(s, global_keymap)
  action = bm.resolve_input_with_keymap(s, global_keymap)
  if action
    action.call
  else
    puts "No action for #{s}"
  end
end


end	# module Redwood
