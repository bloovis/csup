module Redwood

abstract class Mode
  @@keymaps = Hash(String, Keymap).new

  def register_keymap(classname)
    puts "register_keymap for class #{classname}, keymaps #{@@keymaps.object_id}"
    if  @@keymaps.has_key?(classname)
      puts "#{classname} already has a keymap"
      k = @@keymaps[classname]
    else
      puts "Creating keymap for #{classname}"
      k = Keymap.new {}
      @@keymaps[classname] = k
      yield k
    end
    k
  end

  def ancestors
    #puts "Mode.ancestors"
    ["Mode"]
  end

  def initialize
    puts "Mode.initialize"
  end

  def keymap
    @@keymaps[self.class.name]
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

  def resolve_input (c : String) : Proc(Nil) | Nil
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

end	# class Mode

end	# module Redwood
