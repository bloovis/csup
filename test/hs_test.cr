# Test of HorizontalSelector

require "../src/csup"
require "../src/modes/scroll_mode.cr"
require "../src/horizontal_selector"

module Redwood

class StupidMode < ScrollMode
  mode_class left, right

  property selector : HorizontalSelector
  @text = TextLines.new

  register_keymap do |k|
    k.add :left, "Scroll Selector Left", "Left"
    k.add :right, "Scroll Selector Right", "Right"
  end

  def lines
    @text.size
  end

  def [](n) : Text
    @text[n]
  end

  def update
    @text = TextLines.new
    @text << @selector.line
    val = @selector.val.to_i
    (1..val).each do |n|
      l = WidgetArray.new
      l << {:text_color, "This is " }	# This part should be normal color
      l << {:to_me_color, "line #{n+1}."}	# This part should be green
      @text << l
    end
  end

  def initialize(opts = Opts.new)
    super(opts)
    #puts "Initializing StupidMode object #{object_id}"
    @selector = HorizontalSelector.new(
	"Stupid:",
	["1", "2", "3"],
	["One", "Two", "Three"])
    update
  end

  def left(*args)
    @selector.roll_left
    STDERR.puts "left: selector val = #{@selector.val}"
    update
    buffer.mark_dirty
  end

  def right(*args)
    @selector.roll_right
    STDERR.puts "right: selector val = #{@selector.val}"
    update
    buffer.mark_dirty
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

init_managers

mode = StupidMode.new
STDERR.puts "Ancestors of ChildMode:"
STDERR.puts mode.ancestors

start_cursing

buf = BufferManager.spawn("Stupid Mode", mode, Opts.new({:width => 80, :height => 25}))
BufferManager.raise_to_front(buf)

global_keymap = Keymap.new do |k|
  k.add(:quit, "Quit", "q", "C-q")
  k.add(:help, "Help", "h")
end

# bm.draw_screen

# Interactive loop.

event_loop(global_keymap) {|ch| BufferManager.flash "No action for #{ch}"}

stop_cursing

end
