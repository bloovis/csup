
# class InputSequenceAborted < StandardError; end

class Buffer
  property mode : Mode | Nil

  def initialize(mode)	# eventually will be window, mode, width, height, opts={}
    @mode = mode
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

