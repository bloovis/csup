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
    l = WidgetArray.new
    l << {:text_color, "This is " }	# This part should be normal color
    l << {:to_me_color, "line #{n+1}."}	# This part should be green
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
  #BufferManager.say "This is the global quit command."
  stop_cursing
  puts "This is the global quit command."
  exit 0
end

init_managers

mode = StupidMode.new
puts "Ancestors of StupidMode:"
puts mode.ancestors

start_cursing

buf = BufferManager.spawn("Stupid Mode", mode, Opts.new({:width => 80, :height => 25}))
BufferManager.raise_to_front(buf)

global_keymap = Keymap.new do |k|
  k.add(:quit, "Quit", "q", "C-q")
  k.add(:help, "Help", "h")
end

# bm.draw_screen Opts.new({:refresh => true})

# Interactive loop.

event_loop(global_keymap) {|ch| BufferManager.flash "No action for #{ch}"}

stop_cursing

end	# module Redwood
