class Mode
  @@keymaps = Hash(String, Keymap).new

  def register_keymap(classname)
    puts "register_keymap for class #{classname}"
    if  @@keymaps.has_key?(classname)
      k = @@keymaps[classname]
    else
      k = Keymap.new
      @@keymaps[classname] = k
    end
    yield k
    k
  end

  def ancestors
    puts "Mode.ancestors"
    ["Mode"]
  end

  def initialize
    puts "Initializing Mode object #{object_id}"
    register_keymap("Mode") do |k|
      k.add(-> kcommand, "Mode k command", "k")
      k.add(-> lcommand, "Mode l command", "l")
    end
  end

  def keymap
    @@keymaps[self.class.name]
  end

  def kcommand
    puts "Mode.kcommand in object #{object_id}"
    return true
  end

  def lcommand
    puts "Mode.lcommand in object #{object_id}"
    return false
  end

  def process_input(level = 1)
    print ">" * level
    s = gets
    return unless s

    classname = self.class.name
    ancestors.each do |classname|
      puts "Trying keymap for #{classname}"
      next unless @@keymaps.has_key?(classname)
      k = @@keymaps[classname]
      looking = true
      while looking
	k.dump
	if k.has_key?(s)
	  p = k[s]
	  if p.is_a?(Keymap)
	    puts "multi-map!"
	    k = p
	    level += 1
	    print ">" * level
	    s = gets
	    return unless s
	  else
	    p.call
	    return
	  end
	else
	  looking = false
	end
      end
    end
    puts "unknown command '#{s}'"
  end

  def resolve_input (c : String) : Proc(Bool) | Nil
    ancestors.each do |classname|
      next unless @@keymaps.has_key?(classname)
      action = BufferManager.resolve_input_with_keymap(c, @@keymaps[classname])
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

end

