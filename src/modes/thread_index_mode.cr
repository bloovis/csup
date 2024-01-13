require "../csup"
require "../message"
require "../time"
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
  @date_widgets = Array(String).new
  @size_widget_width = 0
  @date_widget_width = 0

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
    old_cursor_thread = cursor_thread
    threadlist = @threadlist
    return unless threadlist

    @threads = Array(MsgThread).new
    threadlist.threads.each_with_index do |thread, i|
      @threads << thread
    end

    @size_widgets = @threads.map { |t| size_widget_for_thread t }
    @size_widget_width = @size_widgets.max_of { |w| w.display_length }
    @date_widgets = @threads.map { |t| date_widget_for_thread t }
    @date_widget_width = @date_widgets.max_of { |w| w.display_length }

    if old_cursor_thread
      set_cursor_pos @threads.index(old_cursor_thread)
    else
      set_cursor_pos curpos
    end

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
    size_widget = @size_widgets[line]
    date_widget = @date_widgets[line]

    starred = t.has_label? :starred

    size_widget_text = size_widget.pad_left(@size_widget_width)
    date_widget_text = date_widget.pad_left(@date_widget_width)

    m = t.msg
    if m
      "#{size_widget_text} #{date_widget_text} #{t.labels.to_a.join(",")} #{m.headers["From"]} / #{m.headers["Subject"]}"
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

  def date_widget_for_thread(t : MsgThread)
    t.date.to_local.to_nice_s
  end

  def cursor_thread : MsgThread?
    if curpos < @threads.size
      @threads[curpos]
    else
      nil
    end
  end

  # Commands

  def select_item
    thread = cursor_thread
    if thread
      BufferManager.flash "Selecting thread at #{@curpos}"
      mode = ThreadViewMode.new(thread, @display_content)
      viewbuf = BufferManager.spawn(thread.subj, mode, Opts.new({:width => 80, :height => 25}))
      BufferManager.raise_to_front(viewbuf)
    else
      BufferManager.flash "No thread at #{@curpos}!"
    end
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
