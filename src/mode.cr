class Object
  def send(action : Symbol)
    puts "Object can't send #{action}!"
  end
end

module Redwood

# We have to use a pseudo-global variable for the keymaps
# because in Crystal, unlike in Ruby, a @@keymaps class variable
# for Mode would get a unique instance for each subclass.
@@keymaps = Hash(String, Keymap).new
def self.keymaps
  @@keymaps
end

# This macro defines a send method that given a symbol, calls the
# method with the same name.  The arguments to the macro are
# the names of the allowed methods.
macro actions(*names)
  def send(action : Symbol)
    case action
    {% for name in names %}
    when {{ name.symbolize }}
      {{ name.id }}
    {% end %}
    else
      #puts "send: unknown method for #{self.class.name}.#{action}, calling superclass"
      super(action)
    end
  end
end

class Mode
  # In each derived class, call the mode_class macro with the names of
  # all methods that are to be bound to keys.  This creates:
  # - an "ancestors" method for the class
  # - a "send" method that invokes the named methods
  macro mode_class(*names)
    CLASSNAME = self.name
    def ancestors
      [CLASSNAME] + super
    end
    Redwood.actions({{*names}})
  end

  def send(action : Symbol)
    #puts "Mode.send: should never get here!"
  end

  property buffer : Buffer?

  def self.register_keymap
    classname = self.name
    #puts "register_keymap for class #{classname}, keymaps #{Redwood.keymaps.object_id}"
    if  Redwood.keymaps.has_key?(classname)
      #puts "#{classname} already has a keymap"
      k = Redwood.keymaps[classname]
    else
      k = Keymap.new {}
      Redwood.keymaps[classname] = k
      #puts "Created keymap for #{classname}, map #{k.object_id}"
      yield k
    end
    k
  end

  def ancestors
    [] of String
  end

  def initialize
    @buffer = nil
    #puts "Mode.initialize"
  end

  def keymap
    Redwood.keymaps[self.class.name]
  end

  def draw; end
  def focus; end
  def blur; end
  def status; ""; end
  def resize(rows, cols); end

  def resolve_input (c : String) : Symbol | Nil
    ancestors.each do |classname|
      next unless Redwood.keymaps.has_key?(classname)
      action = BufferManager.resolve_input_with_keymap(c, Redwood.keymaps[classname])
      return action if action
    end
    nil
  end

  def handle_input(c : String) : Bool
    if action = resolve_input(c)
      send action
      true
    else
      return false
    end
  end

end	# class Mode

end	# module Redwood
