
# class InputSequenceAborted < StandardError; end

class Buffer
  alias BufferOpts = Hash(Symbol, Bool | String)

  getter x : Int32
  getter y : Int32
  getter width : Int32
  getter height : Int32
  getter title : String
  getter atime : Time
  getter mode : Mode | Nil
  getter w : Ncurses::Window
  getter force_to_top : Bool
  getter hidden : Bool
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
    
    #if opts.has_key?(:title)
    #  @title = opts[:title].as(String)
    #else
    #  @title = ""
    #end
    @title = string_opt(opts, :title)
    #if opts.has_key?(:force_to_top)
    #  @force_to_top = opts[:force_to_top].as(Bool)
    #else
    #  @force_to_top = false
    #end
    @force_to_top = bool_opt(opts, :force_to_top)
    #if opts.has_key?(:hidden)
    #  @hidden = opts[:hidden].as(Bool)
    #else
    #  @hidden = false
    #end
    @hidden = bool_opt(opts, :hidden)
    @x, @y, @width, @height = 0, 0, width, height
    @atime = Time.unix 0
    @system = bool_opt(opts, :system)
  end
end

class BufferManager

  # Eventually replace this with focus_buf.
  @focus_buf : Buffer | Nil

  def initialize
    puts "BufferManager.initialize"
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

  def self.ask_getch(help : String) : String
    print "Enter #{help}: "
    gets || ""
  end

  def self.resolve_input_with_keymap(c : String, keymap : Keymap) : Proc(Bool) | Nil
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

end

