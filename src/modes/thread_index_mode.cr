require "../csup"
require "../message"
require "./line_cursor_mode"
require "./thread_view_mode"

module Redwood

class ThreadIndexMode < LineCursorMode
  mode_class help

  @text = Array(String).new
  @threads = Array(MsgThread).new
  @display_content = false

  register_keymap do |k|
    k.add(:help, "help", "h")
  end

  def killable?
    false	# change this to true when we have some derived classes!
  end

  def lines
    @text.size
  end

  def [](n) : Text
    @text[n]
  end

  def initialize(threadlist : ThreadList, @display_content=false)
    super()
    threadlist.threads.each_with_index do |thread, i|
      @threads << thread
      m = thread.msg
      if m
	@text << "Thread #{i}: #{m.headers["From"]} / #{m.headers["Subject"]}"
      else
	@text << "Thread #{i}: No associated message!"
      end
    end
  end

  def select_item
    BufferManager.flash "Selecting thread at #{@curpos}"
    thread = @threads[@curpos]
    mode = ThreadViewMode.new(thread, @display_content)
    viewbuf = BufferManager.spawn(thread.subj, mode, Opts.new({:width => 80, :height => 25}))
    BufferManager.raise_to_front(viewbuf)
  end

  def help
    BufferManager.flash "This is the help command."
    #puts "This is the help command."
  end
end

end	# Redwood
