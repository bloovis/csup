require "./singleton"

module Redwood

## Classic listener/broadcaster paradigm. Handles communication between various
## parts of Sup.
##
## Usage note: don't pass threads around. Neither thread nor message equality is
## defined anywhere in Sup beyond standard object equality. To communicate
## something about a particular thread, just pass a representative message from
## it around.
##
## (This assumes that no message will be a part of more than one thread within a
## single "view". Luckily, that's true.)

# The Crystal implementation differs from Ruby in these ways:
# - The registering class must be a Mode subclass.
# - The mode's update methods (named `handle_{type}_update`) must be listed
#   in the Mode's `mode_class` macro invocation.

class UpdateManager
  singleton_class

  @targets = Hash(Mode, Bool).new

  def initialize
    singleton_pre_init
    singleton_post_init
  end

  def register(o : Mode)
    #STDERR.puts "UpdateManager.register: classname #{o.class.name}"
    @targets[o] = true
  end
  singleton_method register, o

  def unregister(o)
    #STDERR.puts "UpdateManager.unregister: classname #{o.class.name}"
    @targets.delete(o)
  end
  singleton_method unregister, o

  def relay(sender : Object, type : Symbol, *args)
    #STDERR.puts "relay: sender #{sender.class.name}, type #{type}"
    meth = "handle_#{type.to_s}_update"
    @targets.keys.each do |o|
      #STDERR.puts "relay: checking if #{o.class.name} responds to #{meth}"
      if o != sender && o.respond_to?(meth)
	#STDERR.puts "relay: sender #{sender.class.name} sending (#{args[0]?}) to #{o.class.name}.#{meth}"
        o.send meth, sender, *args
      end
    end
  end
  singleton_method relay, type, msg

end	# UpdateManager

end	# Redwood
