module Redwood

class Keymap
  alias Action = Proc(Nil) | Keymap

  property map : Hash(String, Action)
  @desc : Hash(String, String)

  def initialize(&)
    @map = Hash(String, Action).new
    @desc = Hash(String, String).new
    yield self
  end

  def empty?
    return map.empty?
  end

  def add(action : Proc(Nil), description : String, keyname : String)
    #puts "Adding key #{keyname}, description #{description}, action #{action}, map #{map.object_id}"
    @map[keyname] = action
    @desc[keyname] = description
  end

  def has_key?(s : String)
    @map.has_key?(s)
  end

  def [](s : String)
    @map[s]
  end

  def add_multi(description : String, keyname : String)
    #puts "Add multi key #{keyname}, description #{description}, map #{map.object_id}"
    submap = Keymap.new {}
    @map[keyname] = submap
    @desc[keyname] = description
    yield submap
  end

  def dump(m = @map, int level = 1)
    puts "dump level #{level}"
    m.each do |k, v|
      d = @desc.has_key?(k) ? @desc[k] : "<No description>"
      if v.is_a?(Keymap)
	puts "-" * level + "#{k} (#{d}):"
	dump(v.map, level + 1)
      else
	puts "-" * level + "#{k} (#{d}): #{v}"
      end
    end
  end

  def action_for(c : String) : Tuple(Action | Nil, String | Nil)
    if has_key?(c)
      action = @map[c]	# runtime error here
      help = @desc[c]
      {action, help}
    else
      {nil, nil}
    end
  end

end 	# class Keymap

end	# module Redwood

