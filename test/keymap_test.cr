require "../src/keymap"
require "../src/buffer"
require "../src/mode"

class MyMode < Mode
  def ancestors
    puts "MyMode.ancestors"
    ["MyMode"] + super
  end

  def kcommand
    puts "MyMode.kcommand in object #{object_id}"
    return true
  end

  def multicmd
    puts "MyMode.multicmd"
    return false
  end

  def initialize
    super
    puts "Initializing MyMode object #{object_id}"
    register_keymap("MyMode") do |k|
      k.add(-> kcommand, "MyMode k command", "k")
      k.add_multi("MyMode m commands", "m") do |kk|
        kk.add(-> multicmd, "MyMode n command", "n")
      end
    end
  end

end
    
keymaps = Hash(String, Keymap).new
k1 = Keymap.new
k2 = Keymap.new
#puts "typeof(k1} = #{typeof(k1)}"
#keymaps["Mode"] = k1
#keymaps["MyMode"] = k2
keymaps[Mode.name] = k1
keymaps[MyMode.name] = k2
keymaps.each do |k, v|
  puts "Keymap[#{k}] = #{v}"
end

m = MyMode.new
bm = BufferManager.new(m)
puts "Ancestors of MyMode:"
puts m.ancestors
while true
  puts "Command: "
  s = gets || ""
  bm.handle_input s
end
