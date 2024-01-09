require "../src/csup"
require "../src/modes/line_cursor_mode.cr"

module Redwood

class StupidMode < LineCursorMode
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

  def initialize
    super()
    puts "Initializing StupidMode object #{object_id}"
  end

  def help
    BufferManager.flash "This is the help command."
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

cm = Config.new(File.join(BASE_DIR, "config.yaml"))
bm = BufferManager.new
colormap = Colormap.new(File.join(BASE_DIR, "colors.yaml"))
Colormap.reset
Colormap.populate_colormap
mode = StupidMode.new
puts "Ancestors of StupidMode:"
puts mode.ancestors

start_cursing
#w = Ncurses.stdscr
buf = BufferManager.spawn("Stupid Mode", mode, Opts.new({:width => 80, :height => 25}))
BufferManager.raise_to_front(buf)

global_keymap = Keymap.new do |k|
  k.add(:quit, "Quit", "q", "C-q")
  k.add(:help, "Help", "h")
end

bm.draw_screen Opts.new({:refresh => true})
# Interactive loop.
while true
  #ch = bm.ask_getch("Command: ")
  ch = Ncurses.getkey
  bm.erase_flash
  bm.draw_screen
  #print "Command: "
  #ch = gets || ""
  unless bm.handle_input(ch)
    # Either of the following two calls should work.
    #action = BufferManager.resolve_input_with_keymap(ch, global_keymap)
    action = bm.resolve_input_with_keymap(ch, global_keymap)
    if action
      send action
    else
      BufferManager.flash "No action for #{ch}.  Maybe you should try again?"
      #puts "No action for #{ch}"
    end
  end
  bm.draw_screen
end

stop_cursing

end	# module Redwood
