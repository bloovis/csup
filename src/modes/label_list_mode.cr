require "./line_cursor_mode"

module Redwood

class LabelListMode < LineCursorMode
  mode_class select_label, reload, jump_to_next_new, toggle_show_unread_only,
	     handle_added_update

  register_keymap do |k|
    k.add :select_label, "Search by label", "C-m"
    k.add :reload, "Discard label list and reload", '@'
    k.add :jump_to_next_new, "Jump to next new thread", "C-i"
    k.add :toggle_show_unread_only, "Toggle between showing all labels and those with unread mail", 'u'
  end

  def initialize
    @labels = [] of Tuple(String, Int32)	# {label, count}
    @text = TextLines.new
    @unread_only = false
    super
    UpdateManager.register self
    regen_text
  end

  def cleanup
    UpdateManager.unregister self
    super
  end

  def lines; @text.length end
  def [](i); @text[i] end

  def jump_to_next_new(*args)
    n = ((curpos + 1) ... lines).find { |i| @labels[i][1] > 0 } ||
        (0 ... curpos).find { |i| @labels[i][1] > 0 }
    if n
      ## jump there if necessary
      jump_to_line n unless n >= topline && n < botline
      set_cursor_pos n
    else
      BufferManager.flash "No labels messages with unread messages."
    end
  end

  def focus
    reload # make sure unread message counts are up-to-date
  end

  def handle_added_update(*args)
    reload
  end

#protected

  def toggle_show_unread_only(*args)
    @unread_only = !@unread_only
    reload
  end

  def reload(*args)
    regen_text
    buffer.mark_dirty if buffer
  end

  def regen_text
    @text = TextLines.new
    labels = LabelManager.all_labels

    counted = labels.map do |label|
      string = LabelManager.string_for label
      total = Notmuch.count("tag:#{label}")
      unread = (label == "unread")? total : Notmuch.count("tag:#{label} and tag:unread")
      {label, string, total, unread}
    end

    #if HookManager.enabled? "label-list-filter"
    #  counts = HookManager.run "label-list-filter", :counted => counted
    #else
      counts = counted.sort_by { |x| x[1].downcase }	# x[1] = string
    #end

    width = counts.max_of { |x| x[1].size }	# x[1] = string
    tmax  = counts.max_of { |x| x[2] }		# x[2] = total
    umax  = counts.max_of { |x| x[3] }		# x[3] = unread

    if @unread_only
      counts.reject! { |x| x[3] == 0 }		# x[3] = unread
    end

    @labels = [] of Tuple(String, Int32)
    counts.each do |x|
      label =  x[0]
      string = x[1]
      total =  x[2]
      unread = x[3]
      ## if we've done a search and there are no messages for this label, we can delete it from the
      ## list. BUT if it's a brand-new label, the user may not have sync'ed it to the index yet, so
      ## don't delete it in this case.
      ##
      ## this is all a hack. what should happen is:
      ##   TODO make the labelmanager responsible for label counts
      ## and then it can listen to labeled and unlabeled events, etc.
      if total == 0 && !LabelManager::RESERVED_LABELS.includes?(label) && !LabelManager.new_label?(label)
        debug "no hits for label #{label}, deleting"
        LabelManager.delete label
        next
      end

      #fmt = HookManager.run "label-list-format", :width => width, :tmax => tmax, :umax => umax
      #if !fmt
        fmt = "%#{width + 1}s %5d %s, %5d unread"
      #end

      @text << [{(unread == 0 ? :labellist_old_color : :labellist_new_color),
	         sprintf(fmt, string, total, total == 1 ? " message" : "messages", unread)}]
      @labels << {label, unread}
      #yield i if block_given?
    end

    BufferManager.flash "No labels with unread messages!" if counts.empty? && @unread_only
  end

  def select_label(*args)
    label, num_unread = @labels[curpos]
    return unless label
    LabelSearchResultsMode.spawn_nicely label
  end
end

end
