require "../src/modes/scroll_mode.cr"

module Redwood

class StupidMode < ScrollMode
  mode_class help

  register_keymap do |k|
    k.add(:help, "help", "h")
  end

  def lines
    100
  end

  def [](n) : Text
    l = ColoredLine.new
    l << {:text_color, "This is " }	# This part should be normal color
    l << {:to_me_color, "line #{n}."}	# This part should be green
    l
  end

  def initialize(slip_rows = 0, twiddles = true)
    super(slip_rows, twiddles)
    puts "Initializing StupidMode object #{object_id}"
  end

  def help
    BufferManager.say "This is the help command."
    #puts "This is the help command."
  end

end

extend self
actions(quit)

def quit
  BufferManager.say "This is the global quit command."
  #puts "This is the global quit command."
  Ncurses.end
  exit 0
end

bm = BufferManager.new
colormap = Colormap.new
Colormap.reset
Colormap.populate_colormap
mode = StupidMode.new
puts "Ancestors of ChildMode:"
puts mode.ancestors

start_cursing
#w = Ncurses.stdscr
buf = bm.spawn("Stupid Mode", mode, 80, 25)
bm.raise_to_front(buf)

global_keymap = Keymap.new do |k|
  k.add(:quit, "Quit", "q", "C-q")
  k.add(:help, "Help", "h")
end

while true
  ch = bm.ask_getch("Command: ")
  #print "Command: "
  #ch = gets || ""
  unless bm.handle_input(ch)
    # Either of the following two calls should work.
    #action = BufferManager.resolve_input_with_keymap(ch, global_keymap)
    action = bm.resolve_input_with_keymap(ch, global_keymap)
    if action
      send action
    else
      BufferManager.say "No action for #{ch}"
      #puts "No action for #{ch}"
    end
  end
end

stop_cursing

end	# module Redwood
