require "../src/mode"
require "../src/keymap"
require "../src/update"
require "../src/message"

module Redwood

class ListMode < Mode
  def handle_update(type : Symbol, msg : Message)
    puts "ListMode: handling update #{type} for message #{msg.id}"
  end

  def initialize
    super
    puts "Initializing ListMode"
    UpdateManager.register("ListMode", ->handle_update(Symbol, Message))
  end

end

class ViewMode < Mode
  def initialize
    super
    puts "Initializing ViewMode object"
    UpdateManager.register("ViewMode", ->handle_update(Symbol, Message))
  end

  def handle_update(type : Symbol, msg : Message)
    puts "ViewMode: handling update #{type} for message #{msg.id}"
  end

  def mark_starred(msg : Message)
    puts "ViewMode.mark_starred"
    UpdateManager.relay_message(:starred, msg)
  end

end
    
um = UpdateManager.new
lm = ListMode.new	# This would create a Mode object with a different @@keymaps than cm's
vm = ViewMode.new

msg = Message.new("12345")
vm.mark_starred(msg)

end	# module Redwood
