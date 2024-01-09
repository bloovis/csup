# FIXME: make UpdateManager into a generic class.

require "./singleton"
require "./message"

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

# The Crystal implementation differs from Ruby in two significant ways:
# - Updates are allowed only for Message objects.
# - The registering class, instead of providing multiple handle_{type}_update methods,
#   must provide a handle_update method that takes two parameters:
#   - a symbol representing the update type
#   - a Message object


class UpdateManager
  singleton_class

  alias Handler = Proc(Symbol, Message, Nil)

  @@targets = Hash(String, Handler).new

  def initialize
    singleton_pre_init
    singleton_post_init
  end

  def register(o)
    puts "UpdateManager.register: classname #{o.class.name}"
    @@targets[o.class.name] = ->o.handle_update(Symbol, Message)
  end
  singleton_method register, o

  def unregister(o)
    puts "UpdateManager.unregister: classname #{o.class.name}"
    @@targets.delete(o.class.name)
  end
  singleton_method unregister, o

  def relay_message(type : Symbol, msg : Message)
    #meth = "handle_#{type}_update".intern
    @@targets.each do |classname, handler|
      handler.call(type, msg)
    end
  end
  singleton_method relay_message, type, msg

end	# UpdateManager

end	# Redwood
