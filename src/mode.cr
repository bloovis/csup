module Redwood

class Mode
  # In each derived class, call the mode_class macro with the name of the class.
  # This creates an ancestors method for the class, and a CLASSNAME
  # constant that can be used as the argument to register_keymap.
  macro mode_class(name)
    CLASSNAME = {{name.stringify}}

    def ancestors
      [CLASSNAME] + super
    end
  end

  property buffer : Buffer?

  def register_keymap(classname)
    puts "register_keymap for class #{classname}, keymaps #{@keymaps.object_id}"
    if  @keymaps.has_key?(classname)
      puts "#{classname} already has a keymap"
      k = @keymaps[classname]
    else
      puts "Creating keymap for #{classname}"
      k = Keymap.new {}
      @keymaps[classname] = k
      yield k
    end
    k
  end

  def ancestors
    #puts "Mode.ancestors"
    ["Mode"]
  end

  def initialize
    @keymaps = Hash(String, Keymap).new
    puts "Mode.initialize"
  end

  def keymap
    @keymaps[self.class.name]
  end

  def draw; end
  def focus; end
  def blur; end
  def status; ""; end
  def resize(rows, cols); end

  def resolve_input (c : String) : Proc(Nil) | Nil
    ancestors.each do |classname|
      next unless @keymaps.has_key?(classname)
      action = BufferManager.resolve_input_with_keymap(c, @keymaps[classname])
      return action if action
    end
    nil
  end

  def handle_input(c : String) : Bool
    if action = resolve_input(c)
      action.call
      true
    else
      return false
    end
  end

end	# class Mode

end	# module Redwood
