require "../src/supcurses"
require "../src/csup"
require "../src/mode"

module Redwood

class ParentMode < Mode
  mode_class kcommand, lcommand

  register_keymap do |k|
    k.add(:kcommand, "ParentMode k command", "k")
    k.add(:lcommand, "ParentMode l command", "l")
  end

  def initialize
    super
    puts "Initializing ParentMode object #{object_id}"
  end

  def kcommand
    #BufferManager.say "ParentMode.kcommand in object #{object_id}"
    #puts "ParentMode.kcommand in object #{object_id}"
    Ncurses.mvaddstr(0,0, "ParentMode.kcommand in object #{object_id}")
  end

  def lcommand
    #BufferManager.say "ParentMode.lcommand in object #{object_id}"
    #puts "ParentMode.lcommand in object #{object_id}"
    Ncurses.mvaddstr(1,0,"ParentMode.lcommand in object #{object_id}")
  end
end

class ChildMode < ParentMode
  mode_class kcommand, multicmd

  register_keymap do |k|
    k.add(:kcommand, "ChildMode k command", "k")
    k.add_multi("ChildMode m commands", "m") do |kk|
      kk.add(:multicmd, "ChildMode n command", "n")
    end
  end

  def kcommand
    #BufferManager.say "ChildMode.kcommand in object #{object_id}"
    #puts "ChildMode.kcommand in object #{object_id}"
    Ncurses.mvaddstr(2, 0, "ChildMode.kcommand in object #{object_id}")
  end

  def multicmd
    #BufferManager.say "ChildMode.multicmd"
    #puts "ChildMode.multicmd"
    Ncurses.mvaddstr(3,0, "ChildMode.multicmd")
  end

  def initialize
    super
    puts "Initializing ChildMode object #{object_id}"
  end

end
    
extend self

def quit
  #BufferManager.say "This is the global quit command."
  stop_cursing
  puts "This is the global quit command."
  @@global_keymap.dump
  exit 0
end

def help
  #BufferManager.say "This is the global help command."
  #puts "This is the global help command."
  Ncurses.mvaddstr(4, 0, "This is the global help command.")
end

def global_multicmd
  Ncurses.mvaddstr(6, 0, "This is the global multi-command.")
end

actions(quit, help, global_multicmd)

@@global_keymap = Keymap.new do |k|
  k.add(:quit, "Quit", "q", "C-q")
  k.add(:help, "Help", "h")
  k.add_multi("Global g commands", "g") do |kk|
    kk.add(:global_multicmd, "Global n command", "n")
  end
end

init_managers

#pm = ParentMode.new	# This would create a Mode object with a different @@keymaps than cm's
cm = ChildMode.new
puts "Ancestors of ChildMode:"
puts cm.ancestors

start_cursing

#w = Ncurses.stdscr
#buf = Buffer.new(w, cm, 80, 25, title: "Phony buffer")

buf = BufferManager.spawn("Child Mode", cm, Opts.new({:width => 80, :height => 25}))
BufferManager.raise_to_front(buf)
say_id = 0
BufferManager.say("Testing BufferManager.say with a block") {|id| say_id = id}
BufferManager.say("Testing BufferManager.say with reused id #{say_id}", id: say_id)
#buf.write(20, 0, "This is a yellow string", color: :label_color)
buf.draw_status("status line")
#Ncurses.print "\nPress any key to continue:\n"
#ch = Ncurses.getkey
BufferManager.ask_getch("Press any key to continue:")
BufferManager.clear(say_id)

event_loop(@@global_keymap) {|ch| Ncurses.mvaddstr(5, 0, "No action for #{ch}        ")}

end	# module Redwood
