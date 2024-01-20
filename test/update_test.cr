require "../src/mode"
require "../src/keymap"
require "../src/update"
require "../src/message"
require "../src/hook"

module Redwood

class ListMode < Mode
  mode_class handle_starred_update

  def handle_starred_update(sender : Mode, msg : Message)
    puts "ListMode: handling starred update for message #{msg.id}, sender class #{sender.class.name}"
  end

  def initialize
    super
    puts "Initializing ListMode"
    UpdateManager.register(self)
  end

  def stop_update
    UpdateManager.unregister(self)
  end

  def classname
    self.class.name
  end
end

class ViewMode < Mode
  mode_class handle_starred_update

  def initialize
    super
    puts "Initializing ViewMode object"
    UpdateManager.register(self)
  end

  def handle_starred_update(sender : Mode, msg : Message)
    puts "ViewMode: handling starred update for message #{msg.id}"
  end

  def mark_starred(msg : Message)
    puts "ViewMode.mark_starred for message #{msg.id}"
    UpdateManager.relay(self, :starred, msg)
  end

  def stop_update
    UpdateManager.unregister(self)
  end

end
    
puts "Before UpdateManager.new, instantiated? = #{UpdateManager.instantiated?}"
um = UpdateManager.new
puts "After UpdateManager.new, instantiated? = #{UpdateManager.instantiated?}"
lm = ListMode.new
vm = ViewMode.new

puts "ListMode instance class name: #{lm.class.name}"
puts "ViewMode instance class name: #{vm.class.name}"

msg = Message.new
msg.id = "12345"
vm.mark_starred(msg)

lm.stop_update
vm.stop_update

vm.mark_starred(msg)

end	# module Redwood
