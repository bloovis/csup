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

class UpdateManager
  singleton_class(UpdateManager)

  alias Handler = Proc(Symbol, Message, Nil)

  @@targets = Hash(String, Handler).new

  def initialize
    singleton_pre_init
    singleton_post_init
  end

  def register(classname : String, handler : Handler)
    @@targets[classname] = handler
  end
  singleton_method(UpdateManager, register, classname, handler)

  def unregister(classname : String)
    @@targets.delete(classname)
  end
  singleton_method(UpdateManager, unregister, classname)

  def relay_message(type : Symbol, msg : Message)
    #meth = "handle_#{type}_update".intern
    @@targets.each do |classname, handler|
      handler.call(type, msg)
    end
  end
  singleton_method(UpdateManager, relay_message, type, msg)

end	# UpdateManager

end	# Redwood
