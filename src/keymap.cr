module Redwood

class Keymap
  alias Action = Symbol | Keymap
  alias Entry = Tuple(Action, String, Array(String)) # action, help, keynames

  property map = Hash(String, Entry).new	# keyname => entry

  def initialize(&)
    yield self
  end

  def empty?
    return map.empty?
  end

  def add(action : Action, help : String, *keynames)
    keys = [] of String
    keynames.each {|k| keys << k.to_s}
    entry = Entry.new(action, help, keys)
    keys.each do |k|
      raise ArgumentError.new("key '#{k}' already defined (as #{@map[k].first})") if @map.includes? k
      @map[k] = entry
    end
    #puts "Added keys #{keynames}, description #{description}, action #{action}, keymap #{self.object_id}, action map #{@map}"
  end

  def has_key?(s : String)
    @map.has_key?(s)
  end

  def [](s : String)
    @map[s]
  end

  def add_multi(prompt : String, k : String | Char)
    kc = k.to_s
    if @map.member? kc
      action = @map[kc].first
      raise "existing action is not a keymap" unless action.is_a?(Keymap)
      yield action
    else
      submap = Keymap.new {}
      add submap, prompt, kc
      yield submap
    end
  end

  def dump(int level = 1)
    puts "Keymap dump level #{level}:"
    @map.each do |k, entry|
      action = entry[0]
      help = entry[1]
      keys = entry[2]
      if action.is_a?(Keymap)
	puts "-" * level + "#{k} (#{help}):"
	action.dump(level + 1)
      else
	puts "-" * level + "#{k} (#{help}): #{action}"
      end
    end
  end

  def action_for(c : String) : Tuple(Action | Nil, String | Nil)
    #puts "action_for: c #{c}, keymap #{self.object_id}, action map #{@map}"
    if has_key?(c)
      entry = @map[c]
      {entry[0], entry[1]}	# action, help
    else
      {nil, nil}
    end
  end

end 	# class Keymap

end	# module Redwood
