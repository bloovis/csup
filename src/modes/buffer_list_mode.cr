require "./line_cursor_mode"

module Redwood

class BufferListMode < LineCursorMode
  mode_class jump_to_buffer, reload, kill_selected_buffer

  @bufs = Array(Tuple(String, Buffer)).new
  @text = TextLines.new

  register_keymap do |k|
    k.add :jump_to_buffer, "Jump to selected buffer", "C-m"
    k.add :reload, "Reload buffer list", "@"
    k.add :kill_selected_buffer, "Kill selected buffer", "X"
  end

  def initialize
    regen_text
    super
  end

  def lines; @text.size end
  def [](i); @text[i] end

  def focus
    reload # buffers may have been killed or created since last view
    set_cursor_pos 0
  end

  protected def reload(*args)
    regen_text
    buffer.mark_dirty
  end

  protected def regen_text
    @bufs = BufferManager.buffers.
            reject { |name, buf| buf.mode == self || buf.hidden? }.
            sort_by { |name, buf| buf.atime }.
	    reverse
    return if @bufs.size == 0
    width = @bufs.max_of { |name, buf| buf.mode.name.length }
    @text = TextLines.new
    @bufs.each do |name, buf|
      line = WidgetArray.new
      base_color = buf.system? ? :system_buf_color : :regular_buf_color
      line << {:modified_buffer_color, (buf.mode.unsaved? ? "*" : " ")}
      line << {base_color, " " + name}
      @text << line
    end
  end

  protected def jump_to_buffer(*args)
    BufferManager.raise_to_front @bufs[curpos][1]
  end

  protected def kill_selected_buffer(*args)
    reload if BufferManager.kill_buffer_safely @bufs[curpos][1]
  end
end

end
