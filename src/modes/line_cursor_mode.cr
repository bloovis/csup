require "./scroll_mode"

# In this Crystal version of LineCursorMode, we are going to eliminate
# the use of callbacks, which are an ugly ultra-modern hip version of goto.
# Since the only apparent reason for callbacks here is to load more
# lines into the buffer when the cursor approaches the bottom, we can
# surely a find simpler, synchronous, single-threaded way to do that.

module Redwood

## extends ScrollMode to have a line-based cursor.
class LineCursorMode < ScrollMode
  mode_class cursor_down, cursor_up, select_item

  register_keymap do |k|
    ## overwrite scrollmode binding on arrow keys for cursor movement
    ## but j and k still scroll!
    k.add(:cursor_down, "Move cursor down one line", "Down", "j")
    k.add(:cursor_up, "Move cursor up one line", "Up", "k")
    k.add(:select_item, "Select this item", "C-m")
  end

  property curpos = 0

  def initialize(opts = Opts.new)
    @cursor_top = @curpos = opts.delete_int(:skip_top_rows) || 0
{% if false %}
    @load_more_callbacks = []
    @load_more_q = Queue.new
    @load_more_thread = ::Thread.new do
      while true
        e = @load_more_q.pop
        @load_more_callbacks.each { |c| c.call e }
        sleep 0.5
        @load_more_q.pop until @load_more_q.empty?
      end
    end
{% end %}
    super(opts)
  end

  def cleanup
    #@load_more_thread.kill
    super
  end

  def draw
    super
    set_status
  end


  ## callbacks when the cursor is asked to go beyond the bottom
{% if false %}
  def to_load_more &b
    @load_more_callbacks << b
  end
{% end %}

  protected def draw_line(ln, opts = Opts.new)
    #system("echo line_cursor_mode.draw_line: ln #{ln}, curpos #{curpos} >>/tmp/csup.log")
    if ln == @curpos
      super ln, Opts.new({:highlight => true,
			  :debug => opts.bool(:debug) || false,
			  :color => :text_color})
    else
      super ln, Opts.new({:color => :text_color})
    end
  end

  protected def ensure_mode_validity
    super
    #raise @curpos.inspect unless @curpos.is_a?(Integer)
    c = @curpos.clamp topline, botline - 1
    c = @cursor_top if c < @cursor_top
    buffer.mark_dirty unless c == @curpos
    @curpos = c
  end

  protected def set_cursor_pos(p)
    return if @curpos == p
    @curpos = p.clamp @cursor_top, lines
    buffer.mark_dirty if buffer # not sure why the buffer is gone
    set_status
  end

  ## override search behavior to be cursor-based. this is a stupid
  ## implementation and should be made better. TODO: improve.
  protected def search_goto_line(line)
    while line >= botline
      page_down
    end
    while line < topline
      page_up
    end
    set_cursor_pos line
  end

  protected def search_start_line; @curpos end

  protected def line_down # overwrite scrollmode
    super
    #call_load_more_callbacks([topline + buffer.content_height - lines, 10].max) if topline + buffer.content_height > lines
    set_cursor_pos topline if @curpos < topline
  end

  protected def line_up # overwrite scrollmode
    super
    set_cursor_pos botline - 1 if @curpos > botline - 1
  end

  protected def cursor_down
    #call_load_more_callbacks buffer.content_height if @curpos >= lines - [buffer.content_height/2,1].max
    return false unless @curpos < lines - 1

    if Config.bool(:continuous_scroll) && (@curpos == botline - 3 && @curpos < lines - 3)
      # load more lines, one at a time.
      jump_to_line topline + 1
      @curpos += 1
      unless buffer.dirty
        draw_line @curpos - 1
        draw_line @curpos
        set_status
        buffer.commit
      end
    elsif @curpos >= botline - 1
      page_down
      set_cursor_pos topline
    else
      @curpos += 1
      unless buffer.dirty
        draw_line @curpos - 1
        draw_line @curpos
        set_status
        buffer.commit
      end
    end
    true
  end

  protected def cursor_up
    return false unless @curpos > @cursor_top

    if Config.bool(:continuous_scroll) && (@curpos == topline + 2)
      jump_to_line topline - 1
      @curpos -= 1
      unless buffer.dirty
        draw_line @curpos + 1
        draw_line @curpos
        set_status
        buffer.commit
      end
    elsif @curpos == topline
      old_topline = topline
      page_up
      set_cursor_pos [old_topline - 1, topline].max
    else
      @curpos -= 1
      unless buffer.dirty
        draw_line @curpos + 1
        draw_line @curpos
        set_status
        buffer.commit
      end
    end
    true
  end

  protected def page_up # overwrite
    if topline <= @cursor_top
      set_cursor_pos @cursor_top
    else
      relpos = @curpos - topline
      super
      set_cursor_pos topline + relpos
    end
  end

  ## more complicated than one might think. three behaviors.
  protected def page_down
    ## if we're on the last page, and it's not a full page, just move
    ## the cursor down to the bottom and assume we can't load anything
    ## else via the callbacks.
    if topline > lines - buffer.content_height
      set_cursor_pos(lines - 1)

    ## if we're on the last page, and it's a full page, try and load
    ## more lines via the callbacks and then shift the page down
    elsif topline == lines - buffer.content_height
      #call_load_more_callbacks buffer.content_height
      super

    ## otherwise, just move down
    else
      relpos = @curpos - topline
      super
      set_cursor_pos [topline + relpos, lines - 1].min
    end
  end

  protected def jump_to_start
    super
    set_cursor_pos @cursor_top
  end

  protected def jump_to_end
    super if topline < (lines - buffer.content_height)
    set_cursor_pos(lines - 1)
  end


  private def select_item
  end

  private def set_status
    l = lines
    @status = l > 0 ? "line #{@curpos + 1} of #{l}" : ""
  end

{% if false %}
  def call_load_more_callbacks size
    @load_more_q.push size if Config.bool(:load_more_threads_when_scrolling)
  end
{% end %}

end
end