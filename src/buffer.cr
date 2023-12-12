
# class InputSequenceAborted < StandardError; end

class BufferManager

  @mode : Mode

  def initialize(@mode)
  end
    
  def handle_input(c : String)
    @mode.handle_input(c)
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

