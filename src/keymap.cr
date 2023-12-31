module Redwood

class Keymap
  alias Action = Symbol | Keymap

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

  def add(action : Symbol, description : String, *keynames)
    keynames.each do |keyname|
      @map[keyname] = action
      @desc[keyname] = description
    end
    #puts "Added keys #{keynames}, description #{description}, action #{action}, keymap #{self.object_id}, action map #{@map}"
  end

  def has_key?(s : String)
    @map.has_key?(s)
  end

  def [](s : String)
    @map[s]
  end

  def add_multi(description : String, keyname : String)
    submap = Keymap.new {}
    @map[keyname] = submap
    @desc[keyname] = description
    #puts "Added multi key #{keyname}, description #{description}, keymap #{map.object_id}, action map #{@map}"
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
    #puts "action_for: c #{c}, keymap #{self.object_id}, action map #{@map}"
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
