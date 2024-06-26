require "../csup"
require "../message"
require "../time"
require "../tagger"
require "./line_cursor_mode"
require "./thread_view_mode"

module Redwood

class ThreadIndexMode < LineCursorMode
  mode_class load_more_threads, reload,
	     read_and_archive, multi_read_and_archive,
	     toggle_tagged, multi_toggle_tagged, apply_to_tagged,
	     edit_labels, multi_edit_labels, reply_cmd, reply_all,
	     toggle_archived, multi_toggle_archived,
	     toggle_new, multi_toggle_new, jump_to_next_new,
	     toggle_starred, multi_toggle_starred,
	     toggle_deleted, multi_toggle_deleted,
	     toggle_spam, multi_toggle_spam,
	     handle_deleted_update, handle_undeleted_update, handle_poll_update,
	     handle_labeled_update, handle_updated_update,
	     handle_single_message_labeled_update, handle_spammed_update,
	     handle_unspammed_update,
	     undo

  MIN_FROM_WIDTH = 15
  LOAD_MORE_THREAD_NUM = 20

  register_keymap do |k|
    k.add :load_more_threads, "Load #{LOAD_MORE_THREAD_NUM} more threads", 'M'
    k.add :read_and_archive, "Archive thread (remove from inbox) and mark read", 'A'
    k.add :reload, "Refresh view", '@'
    k.add :toggle_archived, "Toggle archived status", 'a'
    k.add :toggle_starred, "Star or unstar all messages in thread", '*'
    k.add :toggle_new, "Toggle new/read status of all messages in thread", 'N'
    k.add :edit_labels, "Edit or add labels for a thread", 'l'
    k.add :toggle_spam, "Mark/unmark thread as spam", 'S'
    k.add :toggle_deleted, "Delete/undelete thread", 'd'
    k.add :jump_to_next_new, "Jump to next new thread", "C-i"
    k.add :reply_cmd, "Reply to latest message in a thread", 'r'
    k.add :reply_all, "Reply to all participants of the latest message in a thread", 'G'
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
  @hidden = Hash(String, Bool).new		# indexed by thread.id

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
    ts = ThreadList.new(translated_query, offset: 0, limit: buffer.content_height)
    @ts = ts
    num = ts.threads.size
    if num == 0
      BufferManager.flash "No matches."
    else
      BufferManager.flash "Found #{num.pluralize "thread"}."
      update
    end
    UpdateManager.register self
  end

  # handle_{type}_update methods invoked by UpdateManager.relay should call
  # this to get the actual thread being updated.  We need to do this because
  # the sender's thread object may be different from the receiver's, even when
  # both refer to the same Notmuch thread.  So we have to find a matching thread
  # based on thread ID.
  def get_update_thread(*args) : MsgThread?
    t = args[1]?
    #STDERR.puts "get_update_thread: t = #{t}"
    if t && t.is_a?(MsgThread)
      #STDERR.puts "get_update_thread: searching for thread id #{t.id}"
      if (ts = @ts) && (t = ts.find_thread(t))
	#STDERR.puts "get_update_thread: found thread id #{t.id}"
        return t
      end
    end
    #STDERR.puts "get_update_thread: couldn't find thread #{t}"
    nil
  end

  # Similar to get_update_thread, except it returns the sender's thread,
  # not the matching thread in this thread list.
  def get_sender_thread(*args) : MsgThread?
    t = args[1]?
    #STDERR.puts "get_update_thread: t = #{t} (#{t.class.name})"
    if t && t.is_a?(MsgThread)
      return t
    else
      return nil
    end
  end

  # This is called from DraftManager.write_draft with the updated
  # thread containing the newly created draft message.  Replace
  # the matching thread in the current thread list with this new thread.
  def handle_updated_update(*args)
    # Get the new thread containing the draft message, and
    # the matching existing thread in the thread list.
    return unless (t = args[1]?) && t.is_a?(MsgThread)
    return unless msg = t.msg
    #STDERR.puts "handle_updated_update: new thread id #{t.id}"
    return unless (ts = @ts) && (oldt = ts.find_thread(t))
    #STDERR.puts "handle_updated_update: old thread id #{oldt.id}"
    return unless l = @lines[oldt]?

    # Replace the old thread's top level message with the new one's.
    # This has the effect of replacing the entire thread.
    #STDERR.puts "handle_updated_update: setting thread msg"
    oldt.set_msg(msg)

    # t.save # do we need this?
    update_text_for_line l
  end

  def handle_single_message_labeled_update(*args)
    ## no need to do anything different here; we don't differentiate
    ## messages from their containing threads
    handle_labeled_update(*args)
  end

  def handle_labeled_update(*args)
    return unless sender_t = get_sender_thread(*args)
    return unless t = get_update_thread(*args)
    return unless l = @lines[t]?
    t.labels = sender_t.labels
    #STDERR.puts "handle_labeled_update: thread #{t.id} (#{t.object_id}), starred = #{t.has_label? :starred}"
    update_text_for_line l
  end

  # Completely reload the thread list, because something happened
  # that could have caused one or more threads to change their visibility
  # or their message tree, and in a way that we can't simulate by hiding
  # or unhiding a previously seen thread.  This can happen if thread
  # wasn't in the initial thread list but should be now, e.g., because
  # it was undeleted or unarchived.
  def reload(*args)
    #STDERR.puts "ThreadIndexMode: reload"
    load_more_threads(0)
  end

  # These update handlers have to decide whether to do an "easy" update or
  # a hard "update".  They can do an "easy" update if the thread being updated
  # was previously seen, so can be hidden or unhidden easily.  If the thread
  # wasn't previously seen, the handlers have to do a "hard" update, which
  # involves completely reloading the thread list for the current query.

  def hide_thread(t : MsgThread)
    @hidden[t.id] = true
  end

  def unhide_thread(t : MsgThread)
    if @hidden.has_key?(t.id)
      @hidden[t.id] = false
    else
      reload
    end
  end

  def hide_foreign_thread(*args)
    if t = get_update_thread(*args)
      #STDERR.puts "hide_foreign_thread: hiding thread #{t.id}"
      hide_thread t
    else
      reload
    end
  end

  def unhide_foreign_thread(*args)
    if t = get_update_thread(*args)
      #STDERR.puts "unhide_foreign_thread: unhiding thread #{t.id}"
      unhide_thread t
    else
      reload
    end
  end

  def handle_deleted_update(*args)
    #STDERR.puts "ThreadIndexMode.handle_deleted_update"
    hide_foreign_thread(*args)
    update
  end

  def handle_undeleted_update(*args)
    #STDERR.puts "ThreadIndexMode.handle_undeleted_update"
    unhide_foreign_thread(*args)
    update
  end

  def handle_spammed_update(*args)
    #STDERR.puts "ThreadIndexMode.handle_spammed_update"
    hide_foreign_thread(*args)
    update
  end

  def handle_unspammed_update(*args)
    #STDERR.puts "ThreadIndexMode.handle_unspammed_update"
    unhide_foreign_thread(*args)
    update
  end

  # This is called after a notmuch poll.  It is passed a notmuch search term
  # that looks like "lastmod:X..Y", which, when added to the existing query,
  # should result in a list of threads that are new/changed since the last poll.
  def handle_poll_update(*args)
    return if @translated_query.empty?
    #STDERR.puts "handle_poll_update started"
    arg = args[1]?
    if arg && arg.is_a?(String) && (ts = @ts)
      # arg is a search term like "lastmod:X..Y"
      #STDERR.puts "handle_poll_update: search terms #{arg}, translated query #{@translated_query}"

      # Add the lastmod search term to our existing query.
      new_query = "(#{@translated_query}) and (#{arg})"

      # Find out how many threads match the new query.  Use that to set
      # a limit on how many threads to fetch for the query.
      count = Notmuch.count(new_query)
      #STDERR.puts "handle_poll_update: new_query #{new_query}, count #{count}"
      return if count == 0
      limit = ts.threads.size + count

      # Load the updated threads into the cache.
      new_ts = ThreadList.new(new_query, offset: 0, limit: limit, force: true)
      #STDERR.puts "handle_poll_update: limit #{limit}, new thread list size #{new_ts.threads.size}"

      # Now reload the entire thread list, but use cached threads
      # if available.
      ts = ThreadList.new(@translated_query, offset: 0, limit: limit, force: false)
      @ts = ts
      @hidden = Hash(String, Bool).new

      BufferManager.flash "#{count.pluralize "thread"} updated"
      #STDERR.puts "handle_poll_update: calling update"
      update
    end
  end

  # Methods for constructing @text

  def update
    old_cursor_thread = cursor_thread
    threadlist = @ts
    #STDERR.puts "update: threadlist is nil: #{threadlist.nil?}"
    return unless threadlist
    #STDERR.puts "update: nthreads = #{threadlist.threads.size}"
    @threads = threadlist.threads.select {|t| !@hidden[t.id]?}
    #STDERR.puts "update: no. of non-hidden threads = #{@threads.size}"
    if @threads.size == 0
      # The thread list is now empty
      regen_text
      return
    end

    @size_widgets = @threads.map { |t| t.size_widget }
    @size_widget_width = @size_widgets.max_of { |w| w.display_length }
    @date_widgets = @threads.map { |t| t.date_widget }
    @date_widget_width = @date_widgets.max_of { |w| w.display_length }

    if old_cursor_thread
      set_cursor_pos @threads.index(old_cursor_thread)
    else
      set_cursor_pos curpos
    end

    regen_text
  end

  def update_text_for_line(l : Int32)
    return unless l # not sure why this happens, but it does, occasionally

    need_update = false

    # and certainly not sure why this happens..
    #
    # probably a race condition between thread modification and updating
    # going on.
    return unless thread = @threads[l]?

    @size_widgets[l] = thread.size_widget
    @date_widgets[l] = thread.date_widget

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
    seen = Hash(String, Bool).new	# Person.to_s => seen

    authors : Array(Person) = t.map do |m, depth, parent|
      next unless m && m.from
      next if seen[m.from.to_s]?
      seen[m.from.to_s] = true
      new[m.from] ||= m.has_label?(:unread)
      #STDERR.puts "from #{m.from} (#{m.from.to_s}), seen #{seen[m.from]?}"
      m.from
    end.compact

    result = Array(NameNewness).new
    authors.each do |a|
      #STDERR.puts "author: #{a.to_s}"
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
    #STDERR.puts "text_for_thread_at: line #{line}, thread #{t.id}, tags #{t.labels}"
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

    directly_participated = t.direct_participants.any?{|p| AccountManager.is_account?(p)}
    participated = directly_participated ||
		   t.participants.any?{|p| AccountManager.is_account?(p)}

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
      {:to_me_color, directly_participated ? ">" : (participated ? "+" : " ")}
    ] + label_widgets + [
      {subj_color, t.subj + (t.subj.empty? ? "" : " ")},
      {:snippet_color, t.snippet},
    ]
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

  def status
    if (l = lines) == 0
      "line 0 of 0"
    else
      "line #{curpos + 1} of #{l}"
    end
  end

  # Commands

  def load_more_threads(*args)
    # These should never be nil.
    return unless old_ts = @ts
    return unless translated_query = @translated_query

    arg = args[0]?
    if arg && arg.is_a?(Int32)
      num = arg
    else
      num = ThreadIndexMode::LOAD_MORE_THREAD_NUM
    end

    # It's too complicated to try to figure out the correct non-zero offset,
    # then merge the new thread list into the old one.  Just start at 0
    # and rebuild the entire thread list.
    offset = 0
    limit = [@threads.size + num, buffer.content_height].max

    #STDERR.puts "load_more_threads: query #{translated_query}, offset #{offset}, limit #{limit}"
    new_ts = ThreadList.new(translated_query, offset: offset, limit: limit)

    new_tags = Tagger(MsgThread).new
    new_tags.setmode(self)

    new_ts.threads.each do |new_t|
      # Find the thread in the old thread list that matches the one in the new list, if any.
      if old_t = old_ts.find_thread(new_t)
	# If the thread from the old thread list was tagged, tag it in the new thread list.
	if @tags.tagged?(old_t)
	  new_tags.tag(new_t)
	end
      end
    end
    @ts = new_ts
    @hidden = Hash(String, Bool).new
    @tags = new_tags
    update
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
    t.load_body
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
    t.save

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
    return unless ts = @ts
    return unless t = ts.find_thread(thread)
    return unless l = @lines[t]?
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

  def cleanup
    #STDERR.puts "ThreadIndexMode.cleanup"
    UpdateManager.unregister self
    super
  end

  # Toggle starred commands

  ## returns an undo lambda
  def actually_toggle_starred(t : MsgThread) : Proc(Nil)
    thread = t
    if t.has_label? :starred # if ANY message has a star
      t.remove_label :starred # remove from all
      t.save
      UpdateManager.relay self, :labeled, t
      return -> do
        if msg = t.msg
	  msg.add_label :starred
	end
	t.save
        UpdateManager.relay self, :labeled, t
        regen_text
	nil
      end
    else
      if msg = t.msg
	#STDERR.puts "adding starred to #{t.id}, #{msg.id}"
	msg.add_label :starred # add only to first
	#STDERR.puts "#{t.id} (#{t.object_id}) has label :starred? #{t.has_label? :starred}"
      end
      t.save
      UpdateManager.relay self, :labeled, t
      return -> do
        t.remove_label :starred
	t.save
        UpdateManager.relay self, :labeled, t
        regen_text
	nil
      end
    end
  end

  def toggle_starred(*args)
    return unless t = cursor_thread
    undo = actually_toggle_starred t
    UndoManager.register("toggling thread starred status", undo) { t.save}
    update_text_for_line curpos
    cursor_down
  end

  def multi_toggle_starred(*args)
    threads = @tags.all
    undos = threads.map {|t| actually_toggle_starred t}
    UndoManager.register("toggling #{threads.size.pluralize "thread"} starred status") do
      undos.each {|u| u.call}
      threads.each { |t| t.save }
      regen_text
    end
    threads.each { |t| t.save }
    regen_text
  end

  # Toggle archived commands

  ## returns an undo lambda
  def actually_toggle_archived(t : MsgThread) : Proc(Nil)
    thread = t
    pos = curpos
    if t.has_label? :inbox
      t.remove_label :inbox
      t.save
      UpdateManager.relay self, :archived, t
      return -> do
        #STDERR.puts "undo lambda applying :inbox"
        thread.apply_label :inbox
	thread.save
        update_text_for_line pos
        UpdateManager.relay self, :unarchived, thread
	nil
      end
    else
      t.apply_label :inbox
      t.save
      #STDERR.puts "relay unarchived thread #{t.id}"
      UpdateManager.relay self, :unarchived, t
      return -> do
        #STDERR.puts "undo lambda removing :inbox"
        thread.remove_label :inbox
	thread.save
        update_text_for_line pos
        UpdateManager.relay self, :unarchived, thread
	nil
      end
    end
  end

  def multi_toggle_archived(*args)
    threads = @tags.all
    undos = threads.map { |t| actually_toggle_archived t }
    #STDERR.puts "multi_toggle_archived: #{threads.size.pluralize "thread"}, #{undos.size.pluralize "undo"}"
    UndoManager.register("archiving/unarchiving #{threads.size.pluralize "thread"}") do
      #STDERR.puts "Undo block in multi_toggle_archived"
      undos.each {|u| u.call }
      threads.each { |t| t.save }
      regen_text
    end
    regen_text
  end

  def toggle_archived(*args)
    return unless t = cursor_thread
    undo = actually_toggle_archived t
    if m = t.msg
      mid = m.id[0,10]+"..."
    else
      mid = "<unknown>"
    end
    UndoManager.register("archiving/unarchiving thread for message #{mid}", undo) do
      update_text_for_line curpos
      t.save
    end
    update_text_for_line curpos
    t.save
  end

  # Toggle new commands

  def toggle_new(*args)
    return unless t = cursor_thread
    t.toggle_label :unread
    update_text_for_line curpos
    cursor_down
    t.save
  end

  def multi_toggle_new(*args)
    threads = @tags.all
    threads.each do |t|
      t.toggle_label :unread
      t.save
    end
    regen_text
  end


  # Toggle tag commands

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

  # Toggle deleted commands

  # Restore the tagged state of an old thread that might not be
  # in the current thread list.  This should be called from an
  # undo proc that changes the visibility of thread due to
  # changing its spam, deleted, or killed tags.  Call it AFTER
  # calling reload, to ensure that the thread list is up-to-date.
  def tag_old_thread(t : MsgThread)
    if (ts = @ts) && (new_t = ts.find_thread(t))
      @tags.tag(new_t)
      update_text_for_thread(new_t)
    end
  end

  ## returns an undo lambda
  def actually_toggle_deleted(t : MsgThread) : Proc(Nil)
    thread = t			# save for undo proc
    tagged = @tags.tagged?(t)	# used only in debug statements
    if t.has_label? :deleted
      #STDERR.puts "actually_toggle_deleted: remove :deleted, thread #{t.object_id}, tagged = #{tagged}"
      t.remove_label :deleted
      t.save
      unhide_thread t
      UpdateManager.relay self, :undeleted, t
      return -> do
        #STDERR.puts "undo lambda add :deleted, thread #{thread.id}, tagged = #{tagged}"
        thread.apply_label :deleted
	t.save
	hide_thread thread
        UpdateManager.relay self, :deleted, thread
	nil
      end
    else
      #STDERR.puts "actually_toggle_deleted: add :deleted, thread #{t.id}, tagged = #{tagged}"
      t.apply_label :deleted
      t.save
      hide_thread t
      UpdateManager.relay self, :deleted, t
      return -> do
        #STDERR.puts "undo lambda remove :deleted, thread #{thread.id}, tagged = #{tagged}"
        thread.remove_label :deleted
	thread.save
	unhide_thread thread
        UpdateManager.relay self, :undeleted, thread
	nil
      end
    end
  end

  def do_multi_toggle_deleted(threads : Array(MsgThread))
    undos = threads.map { |t| actually_toggle_deleted t }
    tagged_threads = @tags.all
    #STDERR.puts "multi_toggle_deleted: #{threads.size.pluralize "thread"}, #{undos.size.pluralize "undo"}"
    UndoManager.register "deleting/undeleting #{threads.size.pluralize "thread"}" do
      #STDERR.puts "Undo block in multi_toggle_deleted"
      if undos.size > 0
	undos.each {|u| u.call }
	#regen_text
	update
      end
      tagged_threads.each { |t| tag_old_thread(t) }
    end
    #regen_text
    update
  end

  def multi_toggle_deleted(*args)
    do_multi_toggle_deleted(@tags.all)
  end

  def toggle_deleted(*args)
    return unless t = cursor_thread
    do_multi_toggle_deleted([t])
  end

  # Toggle spammed commands

  ## returns an undo lambda
  def actually_toggle_spammed(t : MsgThread) : Proc(Nil)
    thread = t
    if t.has_label? :spam
      t.remove_label :spam
      t.save
      unhide_thread t
      UpdateManager.relay self, :unspammed, t
      return -> do
        thread.apply_label :spam
        thread.save
	hide_thread thread
        UpdateManager.relay self, :spammed, thread
	nil
      end
    else
      t.apply_label :spam
      t.save
      hide_thread t
      UpdateManager.relay self, :spammed, t
      return -> do
        thread.remove_label :spam
        thread.save
	unhide_thread thread
        UpdateManager.relay self, :unspammed, thread
	nil
      end
    end
  end

  def do_multi_toggle_spam(threads : Array(MsgThread))
    undos = threads.map { |t| actually_toggle_spammed t }
    tagged_threads = @tags.all
    #threads.each { |t| HookManager.run("mark-as-spam", :thread => t) }
    UndoManager.register "marking/unmarking #{threads.size.pluralize "thread"} as spam" do
      if undos.size > 0
	undos.each {|u| u.call }
	#reload
	#regen_text
	update
      end
      tagged_threads.each { |t| tag_old_thread(t) }
    end
    #reload
    #regen_text
    update
  end

  def multi_toggle_spam(*args)
    do_multi_toggle_spam(@tags.all)
  end

  def toggle_spam(*args)
    return unless t = cursor_thread
    do_multi_toggle_spam([t])
  end


  # Other commands.

  def jump_to_next_new(*args)
    n = ((curpos + 1) ... lines).find { |i| @threads[i].has_label? :unread } ||
        (0 ... curpos).find { |i| @threads[i].has_label? :unread }
    if n
      jump_to_line n unless n >= topline && n < botline
      set_cursor_pos n
    else
      BufferManager.flash "No new messages."
    end
  end

  def apply_to_tagged(*args); @tags.apply_to_tagged; end

  def edit_labels(*args)
    return unless thread = cursor_thread
    speciall = @hidden_labels + LabelManager::RESERVED_LABELS

    old_labels = thread.labels
    pos = curpos

    # Split the thread's label set into two sets of strings:
    # - keepl = special labels to keep
    # - modifyl = labels that can be modified
    keepl_array, modifyl_array = thread.labels.partition { |t| speciall.includes? t }
    keepl = keepl_array.to_set
    modifyl = modifyl_array.to_set
    #STDERR.puts "modifyl = #{modifyl}"

    user_labels = BufferManager.ask_for_labels(:label, "Labels for thread: ",
					       modifyl,
					       @hidden_labels)
    return unless user_labels

    thread.labels = keepl + user_labels
    user_labels.each { |l| LabelManager << l }
    update_text_for_line curpos

    UndoManager.register "labeling thread" do
      thread.labels = old_labels
      update_text_for_line pos
      UpdateManager.relay self, :labeled, thread
      thread.save
    end

    UpdateManager.relay self, :labeled, thread
    #STDERR.puts "edit_labels: calling save_thread"
    thread.save
  end

  def multi_edit_labels(*args)
    threads = @tags.all
    result = BufferManager.ask_for_labels(:labels, "Add/remove labels (use -label to remove): ",
					  Set(String).new,
					  @hidden_labels)
    return unless result
    user_labels = Set(String).new
    deleted_labels = Set(String).new
    result.each do |label|
      if label =~ /^-/
	deleted_labels.add(label[1..])
      else
	user_labels.add(label)
      end
    end
    hl = user_labels.select {|l| @hidden_labels.includes? l }.to_set
    unless hl.size == 0
      BufferManager.flash "'#{hl}' is a reserved label!"
      return
    end

    old_labels = Set(String).new
    threads.each { |t| old_labels += t.labels }

    threads.each do |t|
      deleted_labels.each {|l| t.remove_label l}
      user_labels.each do |l|
	t.apply_label l
	LabelManager << l
      end
      UpdateManager.relay self, :labeled, t
    end

    regen_text

    UndoManager.register "labeling #{threads.size.pluralize "thread"}" do
      threads.each do |t|
        t.labels = old_labels
        UpdateManager.relay self, :labeled, t
        t.save
      end
      regen_text
    end

    threads.each { |t| t.save }
  end

  def reply(type_arg : String)
    return unless t = cursor_thread
    t.load_body
    return unless m = t.latest_message
    mode = ReplyMode.new(m, type_arg)
    BufferManager.spawn "Reply to #{m.subj}", mode
  end

  def reply_cmd(*args)
    reply("none")
  end

  def reply_all(*args)
    reply("all")
  end

  def read_and_archive(*args)
    return unless thread = cursor_thread  # to make sure lambda only knows about 'old' cursor_thread
    was_unread = thread.has_label? :unread

    UndoManager.register "reading and archiving thread" do
      thread.apply_label :inbox
      thread.apply_label :unread if was_unread
      thread.save
      reload
      regen_text
    end

    thread.remove_label :unread
    thread.remove_label :inbox
    thread.save
    reload
    regen_text
  end

  def multi_read_and_archive(*args)
    threads = @tags.all
    was_unread = threads.map { |t| t.has_label? :unread }

    threads.each do |t|
      t.remove_label :unread
      t.remove_label :inbox
      t.save
    end
    reload
    regen_text

    UndoManager.register "reading and archiving #{threads.size.pluralize "thread"}" do
      threads.zip(was_unread).each do |t, u|
	t.apply_label :inbox
	t.apply_label :unread if u
        t.save
      end
      reload
      regen_text
    end
  end

end

end	# Redwood
