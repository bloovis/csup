require "./singleton"
require "./colormap"

module Redwood

# class InputSequenceAborted < StandardError; end

class Buffer
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
		 title = "",
		 force_to_top = false,
		 hidden = false,
		 system = false)
    @w = window
    @mode = mode
    @dirty = true
    @focus = false
    @title = title
    @force_to_top = force_to_top
    @hidden = hidden
    @x, @y, @width, @height = 0, 0, width, height
    @atime = Time.unix 0
    @system = system
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

  @focus_buf : Buffer | Nil  # Eventually replace this with focus_buf.
  @flash : String?

  def initialize
    singleton_pre_init
    puts "BufferManager.initialize"

    @name_map = Hash(String, Buffer).new
    @buffers = Array(Buffer).new
    @focus_buf = nil
    @dirty = true
    @minibuf_stack = Hash(Int32, String).new
    # @minibuf_mutex = Mutex.new
    # @textfields = {}
    @flash = nil
    @shelled = @asking = false
    @in_x = ENV["TERM"] =~ /(xterm|rxvt|screen)/
    @sigwinch_happened = false
    #@sigwinch_mutex = Mutex.new

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

  # Return number of lines in minibuf.
  def minibuf_lines : Int32
#    @minibuf_mutex.synchronize do
      [(@flash ? 1 : 0) +
       (@asking ? 1 : 0) +
       @minibuf_stack.size, 1].max
#    end
  end

  # Return array of all minibuf lines, in order by id.
  def minibuf_all : Array(String)
    @minibuf_stack.keys.sort.map {|i| @minibuf_stack[i]}
  end
  
  def draw_minibuf(refresh = false)
    m = Array(String).new
    #@minibuf_mutex.synchronize do
      m = minibuf_all
      f = @flash
      if f
	m << f
      end
      m << "" if m.empty? unless @asking # to clear it
    #end

    #Ncurses.mutex.lock unless opts[:sync] == false
    Ncurses.attrset Colormap.color_for(:text_color)
    adj = @asking ? 2 : 1
    m.each_with_index do |s, i|
      Ncurses.mvaddstr Ncurses.rows - i - adj, 0, s + (" " * [Ncurses.cols - s.size, 0].max)
    end
    Ncurses.refresh if refresh
    #Ncurses.mutex.unlock unless opts[:sync] == false
  end

  def say(s : String, id = -1, block_given? = true, &b)
    new_id = id == -1

    #@minibuf_mutex.synchronize do
      if new_id
	if @minibuf_stack.size == 0
	  id = 0
	else
	  id = @minibuf_stack.keys.max + 1
	end
      end
      @minibuf_stack[id] = s
      puts "Setting minibuf[#{id}] = #{s}"
    #end

    if new_id
      draw_screen(refresh: true)
    else
      draw_minibuf(refresh: true)
    end

    if block_given?
      begin
        puts "Yielding minibuf id #{id}"
        yield id
      ensure
        puts "Clearing minibuf[#{id}]"
        clear id
      end
    end
    id
  end
  singleton_method(say, id, block_given?, &b)

  # Crystal doesn't have block_given? or allow blocks to be optional, so
  # we provide an alternate version of say that doesn't require a block.
  def say(s : String, id = -1)
    say(s, id: id, block_given?: false) {}
  end
  singleton_method(say, id, block_given?)

  def erase_flash; @flash = nil; end

  def flash(s : String)
    @flash = s
    draw_screen(refresh: true)
  end

  # Deleting a minibuf entry isuch simpler in Crystal than in Ruby, because
  # we use hash instead of a sparse array.
  def clear(id : Int32)
    #@minibuf_mutex.synchronize do
      @minibuf_stack.delete(id)
    #end

    draw_screen(refresh: true)
  end

  # Dummy draw_screen for testing purposes.
  def draw_screen(refresh = false)
    puts "BufferManager.draw_screen, refresh = #{refresh}, minibuf:"
    minibuf_all.each {|s| puts "  " + s}
  end
end

end
