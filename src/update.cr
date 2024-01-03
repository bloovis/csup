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

# The Crystal implementation differs from Ruby in several ways.
# - It only handles updates to Message objects.
# - You must pass self.class.name instead of self to register and unregister.
# - register requires a second parameter, which is a Proc pointing
#   to a handler method that takes two parameters:
#   - a symbol representing the update type
#   - a Message object

class UpdateManager
  singleton_class UpdateManager

  alias Handler = Proc(Symbol, Message, Nil)

  @@targets = Hash(String, Handler).new

  def initialize
    singleton_pre_init
    singleton_post_init
  end

  def register(classname : String, handler : Handler)
    puts "UpdateManager.register: classname #{classname}, handler #{handler}"
    @@targets[classname] = handler
  end
  singleton_method register, classname, handler

  def unregister(classname : String)
    puts "UpdateManager.unregister: classname #{classname}"
    @@targets.delete(classname)
  end
  singleton_method unregister, classname

  def relay_message(type : Symbol, msg : Message)
    #meth = "handle_#{type}_update".intern
    @@targets.each do |classname, handler|
      handler.call(type, msg)
    end
  end
  singleton_method relay_message, type, msg

end	# UpdateManager

end	# Redwood
