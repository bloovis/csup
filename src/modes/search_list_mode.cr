require "./line_cursor_mode"

module Redwood

class SearchListMode < LineCursorMode
  mode_class select_search, reload, jump_to_next_new, toggle_show_unread_only,
	     delete_selected_search, rename_selected_search, edit_selected_search,
	     add_new_search

  register_keymap do |k|
    k.add :select_search, "Open search results", "C-m"
    k.add :reload, "Discard saved search list and reload", '@'
    k.add :jump_to_next_new, "Jump to next new thread", "C-i"
    k.add :toggle_show_unread_only, "Toggle between showing all saved searches and those with unread mail", 'u'
    k.add :delete_selected_search, "Delete selected search", "X"
    k.add :rename_selected_search, "Rename selected search", "r"
    k.add :edit_selected_search, "Edit selected search", "e"
    k.add :add_new_search, "Add new search", "a"
  end

  alias SearchEntry = Tuple(String, Int32)	# {search_name, line_number}

  def initialize
    @searches = Array(SearchEntry).new
    @text = TextLines.new
    @unread_only = false
    super
    UpdateManager.register self
    regen_text
  end

  def cleanup
    #STDERR.puts "SearchListMode cleanup"
    UpdateManager.unregister self
    super
  end

  def lines; @text.size end
  def [](i); @text[i] end

  def jump_to_next_new(*args)
    n = ((curpos + 1) ... lines).find { |i| @searches[i][1] > 0 } || (0 ... curpos).find { |i| @searches[i][1] > 0 }
    if n
      ## jump there if necessary
      jump_to_line n unless n >= topline && n < botline
      set_cursor_pos n
    else
      BufferManager.flash "No saved searches with unread messages."
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
    searches = SearchManager.all_searches
    counted = Array(Tuple(String, String, Int32, Int32)).new
    searches.map do |name|
      search_string = SearchManager.search_string_for(name)
      next unless search_string
      begin
        query = Notmuch.translate_query(search_string)
        total = Notmuch.count(query)
        unread = Notmuch.count("(#{query}) and tag:unread")
      rescue e : Notmuch::ParseError
        BufferManager.flash "Problem: #{e.message}!"
        total = 0
        unread = 0
      end
      counted << {name, search_string, total, unread}
    end
    counts = counted.sort_by { |n, s, t, u| n.downcase }

    n_width = counts.max_of { |n, s, t, u| n.length }
    tmax    = counts.max_of { |n, s, t, u| t }
    umax    = counts.max_of { |n, s, t, u| u }
    s_width = counts.max_of { |n, s, t, u| s.length }

    if @unread_only
      counts.reject! { | n, s, t, u | u == 0 }
    end

    @searches = Array(SearchEntry).new
    counts.each do |name, search_string, total, unread|
      fmt = "%#{n_width + 1}s %5d %s, %5d unread: %s"
      line = WidgetArray.new
      line << {(unread == 0 ? :labellist_old_color : :labellist_new_color),
                sprintf(fmt, name, total, total == 1 ? " message" : "messages", unread, search_string)}
      @text << line
      @searches << {name, unread}
    end

    BufferManager.flash "No saved searches with unread messages!" if counts.empty? && @unread_only
  end

  def select_search(*args)
    name, num_unread = @searches[curpos]
    return unless name
    query = SearchManager.search_string_for(name)
    return unless query
    SearchResultsMode.spawn_from_query(query)
  end

  def delete_selected_search(*args)
    name, num_unread = @searches[curpos]
    return unless name
    reload if SearchManager.delete name
  end

  def rename_selected_search(*args)
    old_name, num_unread = @searches[curpos]
    return unless old_name

    new_name = BufferManager.ask(:save_search, "Rename this saved search: ", old_name)
    return unless new_name && new_name !~ /^\s*$/ && new_name != old_name
    new_name = new_name.strip
    unless SearchManager.valid_name? new_name
      BufferManager.flash "Not renamed: " + SearchManager.name_format_hint
      return
    end
    if SearchManager.all_searches.includes? new_name
      BufferManager.flash "Not renamed: \"#{new_name}\" already exists"
      return
    end
    reload if SearchManager.rename old_name, new_name
    set_cursor_pos @searches.index([new_name, num_unread])||curpos
  end

  def edit_selected_search(*args)
    name, num_unread = @searches[curpos]
    return unless name

    old_search_string = SearchManager.search_string_for name
    return unless old_search_string
    new_search_string = BufferManager.ask :search, "Edit this saved search: ", (old_search_string + " ")
    return unless new_search_string && new_search_string !~ /^\s*$/ && new_search_string != old_search_string
    reload if SearchManager.edit name, new_search_string.strip
    set_cursor_pos @searches.index([name, num_unread])||curpos
  end

  def add_new_search(*args)
    search_string = BufferManager.ask :search, "New search: "
    return unless search_string && search_string !~ /^\s*$/
    name = BufferManager.ask :save_search, "Name this search: "
    return unless name && name !~ /^\s*$/
    name = name.strip
    unless SearchManager.valid_name? name
      BufferManager.flash "Not saved: " + SearchManager.name_format_hint
      return
    end
    if SearchManager.all_searches.includes? name
      BufferManager.flash "Not saved: \"#{name}\" already exists"
      return
    end
    reload if SearchManager.add name, search_string.strip
    newpos = nil
    @searches.each do |n, l|
      if n == name
	newpos = l
	break
      end
    end
    set_cursor_pos(newpos || curpos)
  end
end

end
