require "./singleton"
require "./colormap"

module Redwood

# class InputSequenceAborted < StandardError; end

class Buffer
  alias BufferOpts = Hash(Symbol, Bool | String)
  alias ColorOpts = Hash(Symbol, Symbol)

  getter x : Int32
  getter y : Int32
  getter width : Int32
  getter height : Int32
  getter title : String
  getter atime : Time
  getter mode : Mode | Nil
  getter w : Ncurses::Window
  property force_to_top : Bool
  property hidden : Bool
  getter system : Bool

  def string_opt(opts : BufferOpts, key : Symbol) : String
    if opts.has_key?(key)
      val = opts[key]
      if val.is_a?(String)
	return val
      else
	return ""
      end
    else
      return ""
    end
  end
    
  def bool_opt(opts : BufferOpts, key : Symbol) : Bool
    if opts.has_key?(key)
      val = opts[key]
      if val.is_a?(Bool)
	return val
      else
	return false
      end
    else
      return false
    end
  end

  def initialize(window, mode, width, height,
		 opts : BufferOpts)
    @w = window
    @mode = mode
    @dirty = true
    @focus = false
    @title = string_opt(opts, :title)
    @force_to_top = bool_opt(opts, :force_to_top)
    @hidden = bool_opt(opts, :hidden)
    @x, @y, @width, @height = 0, 0, width, height
    @atime = Time.unix 0
    @system = bool_opt(opts, :system)
  end

  def content_height; @height - 1; end
  def content_width; @width; end

  def resize(rows, cols)
    return if cols == @width && rows == @height
    @width = cols
    @height = rows
    @dirty = true
    mode.resize rows, cols
  end

  def redraw(status)
    if @dirty
      draw status
    else
      draw_status status
    end

    commit
  end

  def mark_dirty; @dirty = true; end

  def commit
    @dirty = false
    @w.noutrefresh
  end

  def draw(status)
    @mode.draw
    draw_status status
    commit
    @atime = Time.now
  end

  ## s nil means a blank line!
  def write(y, x, s, color = :none, highlight = false, no_fill = false)
    return if x >= @width || y >= @height

    @w.attrset Colormap.color_for(color, highlight)
    s ||= ""
    maxl = @width - x # maximum display width width

    # fill up the line with blanks to overwrite old screen contents
    @w.mvaddstr(y, x, " " * maxl) unless no_fill

    @w.mvaddstr y, x, s.slice_by_display_length(maxl)
  end

  def clear
    @w.clear
  end

  def draw_status(status)
    write @height - 1, 0, status, {:color => :status_color}
  end

  def focus
    @focus = true
    @dirty = true
    @mode.focus
  end

  def blur
    @focus = false
    @dirty = true
    @mode.blur
  end
end

class BufferManager
  singleton_class BufferManager

  # Eventually replace this with focus_buf.
  @focus_buf : Buffer | Nil

  def initialize
    singleton_pre_init
    puts "BufferManager.initialize"
    singleton_post_init
  end
    
  def focus_on(buf : Buffer)
    @focus_buf = buf
  end

  def handle_input(c : String)
    b = @focus_buf
    if b
      m = b.mode
      if m
	m.handle_input(c)
      else
	puts "Buffer has no mode!"
      end
    else
      puts "BufferManager.handle_input: no focus_buf!"
    end
  end

  def ask_getch(help : String) : String
    print "Enter #{help}: "
    gets || ""
  end
  singleton_method ask_getch, help

  def resolve_input_with_keymap(c : String, keymap : Keymap) : Proc(Nil) | Nil
    action, text = keymap.action_for c
    return nil if action.nil? || text.nil?
    while action.is_a? Keymap # multi-key commands, prompt
      key = BufferManager.ask_getch(text || "")
      unless key # user canceled, abort
        #erase_flash
        #raise InputSequenceAborted
      end
      action, text = action.action_for(key) if action.has_key?(key)
    end
    action
  end
  singleton_method resolve_input_with_keymap, c, keymap

end

end
