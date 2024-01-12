require "../csup"
require "../message"
require "./line_cursor_mode"
require "./thread_view_mode"

module Redwood

class ThreadIndexMode < LineCursorMode
  mode_class help

  @text = Array(String).new
  @lines = Hash(MsgThread, Int32).new
  @threads = Array(MsgThread).new
  @display_content = false
  @query = ""
  @threadlist : ThreadList?
  @size_widgets = Array(String).new

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

  def initialize(@query, @display_content=false)
    super()
    @threadlist = ThreadList.new(@query, offset: 0, limit: buffer.content_height)
    update
  end

  # Methods for constructing @text

  def update
    threadlist = @threadlist
    return unless threadlist

    @threads = Array(MsgThread).new
    threadlist.threads.each_with_index do |thread, i|
      @threads << thread
    end

    @size_widgets = @threads.map { |t| size_widget_for_thread t }
    regen_text
  end

  def regen_text
    @text = Array(String).new
    @lines = Hash(MsgThread, Int32).new
    @threads.each_with_index do |t, i|
      @text << text_for_thread_at i
      @lines[t] = i
    end
  end

  def text_for_thread_at(line : Int32) : String
    t = @threads[line]
    text_for_thread(t, line)
  end

  def text_for_thread(t : MsgThread, line : Int32)
    size_widget = @size_widgets[line]
    m = t.msg
    if m
      "#{size_widget} #{m.headers["From"]} / #{m.headers["Subject"]}"
    else
      "Thread has no associated message!"
    end
  end

  def size_widget_for_thread(t : MsgThread)
    case t.size
    when 1
      ""
    else
      "(#{t.size})"
    end
  end

  # Commands

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

  def set_status
    l = lines
    @status = l > 0 ? "\"#{@query}\" line #{@curpos + 1} of #{l}" : ""
  end

end

end	# Redwood
