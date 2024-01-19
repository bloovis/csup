require "../csup"
require "../message"
require "../time"
require "../tagger"
require "./line_cursor_mode"
require "./thread_view_mode"

module Redwood

class ThreadIndexMode < LineCursorMode
  mode_class help

  MIN_FROM_WIDTH = 15

  @text = Array(Text).new # Array(String).new
  @lines = Hash(MsgThread, Int32).new
  @threads = Array(MsgThread).new
  @display_content = false
  @query = ""
  @threadlist : ThreadList?
  @size_widgets = Array(String).new
  @date_widgets = Array(String).new
  @size_widget_width = 0
  @date_widget_width = 0
  @hidden_labels = Set(String).new

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
    @tags = Tagger(MsgThread).new
    @threadlist = ThreadList.new(@query, offset: 0, limit: buffer.content_height)
    @hidden_labels = LabelManager::HIDDEN_RESERVED_LABELS +
		     Set.new(Config.strarray(:hidden_labels))
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
    @text = Array(Text).new
    @lines = Hash(MsgThread, Int32).new
    @threads.each_with_index do |t, i|
      @text << text_for_thread_at i
      @lines[t] = i
    end
  end

  ## preserve author order from the thread
  alias NameNewness = Tuple(String, Bool)

  def author_names_and_newness_for_thread(t : MsgThread, limit = 0) : Array(NameNewness)
    new = Hash(Person, Bool).new	# Person => newness
    seen = Hash(Person, Bool).new	# Person => seen

    authors : Array(Person) = t.map do |m, depth, parent|
      next unless m && m.from
      new[m.from] ||= m.has_label?(:unread)
      next if seen[m.from]?
      seen[m.from] = true
      m.from
    end.compact

    result = Array(NameNewness).new
    authors.each do |a|
      break if limit && result.size >= limit
      name = if AccountManager.is_account?(a)
        "me"
      elsif t.authors.size == 1
        a.mediumname
      else
        a.shortname
      end
      name ||= "nobody"
      result << {name, new[a]}
    end

    if result.size == 1 && result[0][0] == "me"
      newness = result[0][1]
      recipients = t.participants - t.authors
      num_recipients = recipients.size
      if num_recipients > 0
        result = recipients.map do |r|
          break if limit && result.size >= limit
          name = (num_recipients == 1) ? r.mediumname : r.shortname
          {"(#{name})", newness}
        end
      end
    end

    result || Array(NameNewness).new
  end

  AUTHOR_LIMIT = 5
  def text_for_thread_at(line : Int32) : Text
    t = @threads[line]
    size_widget = @size_widgets[line]
    date_widget = @date_widgets[line]

    starred = t.has_label? :starred

    ## format the from column
    cur_width = 0
    ann = author_names_and_newness_for_thread t, AUTHOR_LIMIT
    from = WidgetArray.new
    ann.each_with_index do |(name, newness), i|
      break if cur_width >= from_width
      last = i == ann.size - 1

      abbrev =
        if cur_width + name.display_length > from_width
          name.slice_by_display_length(from_width - cur_width - 1) + "."
        elsif cur_width + name.display_length == from_width
          name.slice_by_display_length(from_width - cur_width)
        else
          if last
            name.slice_by_display_length(from_width - cur_width)
          else
            name.slice_by_display_length(from_width - cur_width - 1) + ","
          end
        end

      cur_width += abbrev.display_length

      if last && from_width > cur_width
        abbrev += " " * (from_width - cur_width)
      end

      from << {(newness ? :index_new_color : (starred ? :index_starred_color : :index_old_color)), abbrev}
    end

    subj_color =
      if t.has_label?(:draft)
        :index_draft_color
      elsif t.has_label?(:unread)
        :index_new_color
      elsif starred
        :index_starred_color
      elsif Colormap.sym_is_defined(:index_subject_color)
        :index_subject_color
      else
        :index_old_color
      end

    size_widget_text = size_widget.pad_left(@size_widget_width)
    date_widget_text = date_widget.pad_left(@date_widget_width)

    label_widgets = WidgetArray.new
    (t.labels - @hidden_labels).to_a.sort.map do |label|
      label_widgets << {:label_color, "#{label} "}
    end

    [
      {:tagged_color, @tags.tagged?(t) ? ">" : " "},
      {:date_color, date_widget_text},
      {:starred_color, (starred ? "*" : " ")},
    ] + from + [
      {:size_widget_color, size_widget_text},
      {:with_attachment_color , t.labels.member?(:attachment) ? "@" : " "},
#      {:to_me_color, directly_participated ? ">" : (participated ? '+' : " ")},
    ] + label_widgets + [
      {subj_color, t.subj + (t.subj.empty? ? "" : " ")},
#      {:snippet_color, t.snippet},
    ]
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

  def from_width
    if buffer
      [(buffer.content_width.to_f * 0.2).to_i, MIN_FROM_WIDTH].max
    else
      MIN_FROM_WIDTH # not sure why the buffer is gone
    end
  end

  # Commands

  def select_item
    thread = cursor_thread
    if thread
      BufferManager.flash "Selecting thread at #{@curpos}"
      mode = ThreadViewMode.new(thread)
      viewbuf = BufferManager.spawn(thread.subj, mode)
      BufferManager.draw_screen
      mode.jump_to_first_open if Config.bool(:jump_to_open_message)
      BufferManager.draw_screen # lame TODO: make this unnecessary
      ## the first draw_screen is needed before topline and botline
      ## are set, and the second to show the cursor having moved
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
