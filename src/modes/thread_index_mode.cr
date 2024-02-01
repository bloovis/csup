require "../csup"
require "../message"
require "../time"
require "../tagger"
require "./line_cursor_mode"
require "./thread_view_mode"

module Redwood

class ThreadIndexMode < LineCursorMode
  mode_class load_more_threads, toggle_archived, multi_toggle_archived,
	     toggle_tagged, multi_toggle_tagged, apply_to_tagged,
	     handle_deleted_update, handle_undeleted_update, handle_poll_update,
	     undo

  MIN_FROM_WIDTH = 15
  LOAD_MORE_THREAD_NUM = 20

  register_keymap do |k|
    k.add :load_more_threads, "Load #{LOAD_MORE_THREAD_NUM} more threads", 'M'
    k.add :toggle_archived, "Toggle archived status", 'a'
    k.add :toggle_tagged, "Tag/untag selected thread", 't'
    k.add :apply_to_tagged, "Apply next command to all tagged threads", '+', '='
    k.add :undo, "Undo the previous action", 'u'
  end

  @text = Array(Text).new # Array(String).new
  @lines = Hash(MsgThread, Int32).new
  @threads = Array(MsgThread).new
  @query = ""
  @translated_query = ""
  @ts : ThreadList?
  @size_widgets = Array(String).new
  @date_widgets = Array(String).new
  @size_widget_width = 0
  @date_widget_width = 0
  @hidden_labels = Set(String).new
  @hidden_threads = Set(MsgThread).new

  def killable?
    true
  end

  def lines
    @text.size
  end

  def [](n) : Text
    @text[n]
  end

  def initialize(@query : String, hidden_labels = [] of Symbol)
    super()
    translated_query = Notmuch.translate_query(@query)
    @translated_query = translated_query
    @tags = Tagger(MsgThread).new
    @tags.setmode(self)
    @hidden_labels = LabelManager::HIDDEN_RESERVED_LABELS +
		     Set.new(Config.strarray(:hidden_labels)) +
		     Set.new(hidden_labels.map(&.to_s))
    @ts = ThreadList.new(translated_query, offset: 0, limit: buffer.content_height)
    if ts = @ts
      num = ts.threads.size
      if num == 0
	BufferManager.flash "No matches."
      else
	BufferManager.flash "Found #{num.pluralize "thread"}."
        update
      end
    end
    UpdateManager.register self
  end

  # handle_{type}_update methods invoked by UpdateManager.relay should call
  # this to get the actual thread being updated.  We need to do this because
  # the sender's thread object may be different from the receiver's, even when
  # both refer to the same Notmuch thread.  So we have to find a matching thread
  # based on the sent thread's top message's ID.
  def get_update_thread(*args) : MsgThread?
    t = args[1]?
    if t && t.is_a?(MsgThread)
      if (ts = @ts) && (t = ts.find_thread(t))
        return t
      end
    end
  end

  def handle_deleted_update(*args)
    t = get_update_thread(*args)
    if t
      hide_thread t
    end
    update
  end

  def handle_undeleted_update(*args)
    t = get_update_thread(*args)
    if t
      add_or_unhide t
    end
  end

  # This is called after a notmuch poll.  It is passed a notmuch search term
  # that looks like "lastmod:X..Y", which, when added to the existing query,
  # should result in a list of threads that are new/changed since the last poll.
  def handle_poll_update(*args)
    #STDERR.puts "handle_poll_update started"
    arg = args[1]?
    if arg && arg.is_a?(String) && (ts = @ts)
      # arg is a search term like "(lastmod:X..Y)"
      #STDERR.puts "handle_poll_update: search terms #{arg}, translated query #{@translated_query}"

      # Get the list of updated threads.
      query = "(#{@translated_query}) and (#{arg})"
      new_ts = ThreadList.new(query, offset: 0, limit: 100)
      n = new_ts.threads.size

      # Run through the old thread list, and add to the new list any thread
      # that is not already in the new list.
      ts.threads.each do |thread|
        new_ts.threads << thread unless new_ts.find_thread(thread)
      end

{% if false %}
      # If any of the updated threads are already in the existing thread list,
      # replace their top-level messages.  Otherwise add the updated thread
      # to the existing thread list.
      new_ts.threads.each do |thread|
        if t = ts.find_thread(thread)
	  if msg = thread.msg
	    t.set_msg(msg)
	  end
	else
	  ts.threads << thread
	end
      end
{% end %}

      # Replace this thread list with the new one.
      @ts = new_ts
      BufferManager.flash "#{n.pluralize "thread"} updated"
      update
    end
  end

  # Methods for constructing @text

  def update
    old_cursor_thread = cursor_thread
    threadlist = @ts
    return unless threadlist

    @threads = threadlist.threads.select {|t|!@hidden_threads.includes?(t)}

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

  def hide_thread(t : MsgThread)
    return unless i = @threads.index(t)
    #STDERR.puts "hide_thread: before hiding thread #{i}, nthreads = #{@threads.size}"
    raise "already hidden" if @hidden_threads.includes?(t)
    @hidden_threads.add(t)
    @threads.delete_at i
    @size_widgets.delete_at i
    @date_widgets.delete_at i
    #@patchwork_widgets.delete_at i if @patchwork_widgets
    @tags.drop_tag_for t
    #STDERR.puts "hide_thread: after hiding thread #{i}, nthreads = #{@threads.size}"
  end

  def update_text_for_line(l : Int32)
    return unless l # not sure why this happens, but it does, occasionally

    need_update = false

    # and certainly not sure why this happens..
    #
    # probably a race condition between thread modification and updating
    # going on.
    return if @threads[l].empty?

    @size_widgets[l] = size_widget_for_thread @threads[l]
    @date_widgets[l] = date_widget_for_thread @threads[l]

    ## if a widget size has increased, we need to redraw everyone
    need_update =
      (@size_widgets[l].size > @size_widget_width) ||
      (@date_widgets[l].size > @date_widget_width)

    if need_update
      update
    else
      @text[l] = text_for_thread_at l
      buffer.mark_dirty if buffer
    end
  end

  def update_text_for_thread(thread : MsgThread)
    return unless ts = @ts
    return unless t = ts.find_thread(thread)
    return unless i = @threads.index(t)
    @threads[i] = thread
    update_text_for_line(i)
  end

  def regen_text
    @text = Array(Text).new
    @lines = Hash(MsgThread, Int32).new
    @threads.each_with_index do |t, i|
      @text << text_for_thread_at i
      @lines[t] = i
    end
    buffer.mark_dirty if buffer
    #STDERR.puts "regen_text: nlines = #{@text.size}"
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
      {:with_attachment_color , t.labels.includes?("attachment") ? "@" : " "},
#      {:to_me_color, directly_participated ? ">" : (participated ? '+' : " ")},
    ] + label_widgets + [
      {subj_color, t.subj + (t.subj.empty? ? "" : " ")},
      {:snippet_color, t.snippet},
    ]
  end

  def add_or_unhide(t : MsgThread)
    if t
      @hidden_threads.delete t
      update
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

  def from_width
    if buffer
      [(buffer.content_width.to_f * 0.2).to_i, MIN_FROM_WIDTH].max
    else
      MIN_FROM_WIDTH # not sure why the buffer is gone
    end
  end

  def set_status
    l = lines
    @status = l > 0 ? "\"#{@query}\" line #{@curpos + 1} of #{l}" : ""
  end

  # Commands

  def load_more_threads(*args)
    arg = args[0]?
    if arg && arg.is_a?(Int32)
      num = arg
    else
      num = ThreadIndexMode::LOAD_MORE_THREAD_NUM
    end
    offset = 0
    limit = @threads.size + num
    if translated_query = @translated_query
      @ts = ThreadList.new(translated_query, offset: offset, limit: limit)
      update
    end
  end

  def undo(*args)
    UndoManager.undo
  end

  def select_item(*args)
    return unless t = cursor_thread
    do_select(t) {}
  end

  def do_select(t : MsgThread, &when_done)
    num = t.size
    message = "Loading #{num.pluralize "message body"}..."
    BufferManager.flash(message)
    t.reload
    mode = ThreadViewMode.new(t, self)
    viewbuf = BufferManager.spawn(t.subj, mode)
    #STDERR.puts "Spawned ThreadViewMode"
    BufferManager.draw_screen
    if Config.bool(:jump_to_open_message)
       mode.jump_to_first_open
     end
    BufferManager.draw_screen # lame TODO: make this unnecessary
    ## the first draw_screen is needed before topline and botline
    ## are set, and the second to show the cursor having moved

    t.remove_label :unread
    Notmuch.save_thread t

    update_text_for_line curpos
    UpdateManager.relay self, :read, t
    when_done.call
    BufferManager.flash("")
  end

  ## these two methods are called by thread-view-modes when the user
  ## wants to view the previous/next thread without going back to
  ## index-mode. we update the cursor as a convenience.
  def launch_next_thread_after(thread, &b)
    launch_another_thread(thread, 1, &b)
  end

  def launch_prev_thread_before(thread, &b)
    launch_another_thread(thread, -1, &b)
  end

  def launch_another_thread(thread, direction, &b)
    return unless l = @lines[thread]
    target_l = l + direction
    t = if target_l >= 0 && target_l < @threads.length
      @threads[target_l]
    end

    if t # there's a next thread
      set_cursor_pos target_l # move out of mutex?
      do_select(t, &b)
    else # no next thread. call the block anyways
      b.call
    end
  end

  ## returns an undo lambda
  def actually_toggle_archived(t : MsgThread) : Proc(Nil)
    thread = t
    pos = curpos
    if t.has_label? :inbox
      t.remove_label :inbox
      UpdateManager.relay self, :archived, t
      return -> do
        #STDERR.puts "undo lambda applying :inbox"
        thread.apply_label :inbox
        update_text_for_line pos
        UpdateManager.relay self, :unarchived, thread
      end
    else
      t.apply_label :inbox
      UpdateManager.relay self, :unarchived, t
      return -> do
        #STDERR.puts "undo lambda removing :inbox"
        thread.remove_label :inbox
        update_text_for_line pos
        UpdateManager.relay self, :unarchived, thread
      end
    end
  end

  def multi_toggle_archived(*args)
    threads = @tags.all
    undos = threads.map { |t| actually_toggle_archived t }
    #STDERR.puts "multi_toggle_archived: #{threads.size.pluralize "thread"}, #{undos.size.pluralize "undo"}"
    UndoManager.register("deleting/undeleting #{threads.size.pluralize "thread"}") do
      #STDERR.puts "Undo block in multi_toggle_archived"
      undos.each {|u| u.call }
      regen_text
      threads.each { |t| Notmuch.save_thread t }
    end
    regen_text
    threads.each { |t| Notmuch.save_thread t }
  end

  def multi_toggle_tagged(*args)
    @tags.drop_all_tags
    regen_text
  end

  def toggle_tagged(*args)
    return unless t = cursor_thread
    @tags.toggle_tag_for t
    update_text_for_line curpos
    cursor_down
  end

  def toggle_archived(*args)
    return unless t = cursor_thread
    undo = actually_toggle_archived t
    if m = t.msg
      mid = m.id[0,10]+"..."
    else
      mid = "<unknown>"
    end
    UndoManager.register("deleting/undeleting thread for message #{mid}", undo) do
      update_text_for_line curpos
      Notmuch.save_thread t
    end
    update_text_for_line curpos
    Notmuch.save_thread t
  end

  def apply_to_tagged(*args); @tags.apply_to_tagged; end

end

end	# Redwood
