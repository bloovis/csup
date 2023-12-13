require "../src/keymap"
require "../src/buffer"
require "../src/mode"

class ParentMode < Mode
  def initialize
    puts "Initializing ParentMode object #{object_id}"
    register_keymap("ParentMode") do |k|
      k.add(-> kcommand, "ParentMode k command", "k")
      k.add(-> lcommand, "ParentMode l command", "l")
    end
  end

  def ancestors
    #puts "ParentMode.ancestors"
    ["ParentMode"] + super
  end

  def kcommand
    puts "ParentMode.kcommand in object #{object_id}"
    return true
  end

  def lcommand
    puts "ParentMode.lcommand in object #{object_id}"
    return false
  end
end

class ChildMode < ParentMode
  def ancestors
    #puts "ChildMode.ancestors"
    ["ChildMode"] + super
  end

  def kcommand
    puts "ChildMode.kcommand in object #{object_id}"
    return true
  end

  def multicmd
    puts "ChildMode.multicmd"
    return false
  end

  def initialize
    super
    puts "Initializing ChildMode object #{object_id}"
    register_keymap("ChildMode") do |k|
      k.add(-> kcommand, "ChildMode k command", "k")
      k.add_multi("ChildMode m commands", "m") do |kk|
        kk.add(-> multicmd, "ChildMode n command", "n")
      end
    end
  end

end
    
bm = BufferManager.new
#pm = ParentMode.new	# This would create a Mode object with a different @@keymaps than cm's
cm = ChildMode.new
buf = Buffer.new(cm)
bm.focus_on(buf)
puts "Ancestors of ChildMode:"
puts cm.ancestors
while true
  print "Command: "
  s = gets || ""
  bm.handle_input s
end
