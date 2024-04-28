module Redwood

# We have to use pseudo-global variables for keymaps and global_keymap,
# because in Crystal, unlike in Ruby, if these were class variables
# for Mode, they would get a unique instance for each subclass of Mode.
@@keymaps = Hash(String, Keymap).new
def self.keymaps
  @@keymaps
end

@@global_keymap : Keymap?
def self.global_keymap
  @@global_keymap
end
def self.global_keymap=(map)
  @@global_keymap = map
end

class Keymap
  alias Action = String | Keymap
  alias Entry = Tuple(Action, String, Array(String)) # action, help, keynames

  property map = Hash(String, Entry).new	# keyname => entry
  property order = Array(Entry).new

  def initialize(&)
    yield self
  end

  def empty?
    return map.empty?
  end

  def add(action : String | Symbol | Keymap, help : String, *keynames)
    keys = [] of String
    keynames.each {|k| keys << k.to_s}
    if action.is_a?(Symbol)
      action = action.to_s
    end
    entry = Entry.new(action, help, keys)
    @order << entry
    keys.each do |k|
      raise ArgumentError.new("key '#{k}' already defined (as #{@map[k].first})") if @map.includes? k
      @map[k] = entry
    end
    if keys.size == 0
      raise "Key list for action #{action} is empty!"
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

  def keysyms : Set(String)
    s = Set(String).new
    @map.each do |k, entry|
      keys = entry[2]
      keys.each {|k| s.add(k)}
    end
    return s
  end

  alias KeyHelp = Tuple(String, String)	# {keynames, helpstring}

  # Change an internal keyname to a more user-friendly name
  def fix_name(k : String) : String
    case k
    when "C-m"
      "Enter"
    when "C-i"
      "Tab"
    when " "
      "Space"
    else
      k
    end
  end

  def help_lines(except_for = Set(String).new, prefix="") : Array(KeyHelp)
    lines = Array(KeyHelp).new
    @order.each do |entry|
      action = entry[0]
      help = entry[1]
      keys = entry[2]
      valid_keys = keys.select { |k| !except_for.includes?(k) }
      next if valid_keys.size == 0
      case action
      when String
        keynames = valid_keys.map { |k| prefix + fix_name(k) }.join(", ")
        lines << {keynames, help}
      when Keymap
        lines += action.help_lines(Set(String).new, prefix + keys.first)
      end
    end		# .compact -- why was this here?
    return lines
  end

  def help_text(except_for=Set(String).new) : String
    lines = help_lines except_for
    llen = lines.max_of { |kh| kh[0].size }
    lines.map { |a, b| sprintf " %#{llen}s : %s", a, b }.join("\n")
  end

  # Load user-defined key bindings from keymap.yaml.
  # The file looks like this:
  #   modename1:
  #     action1:
  #       - key1
  #       - key2
  #       [...]
  #     action2:
  #       [...]
  #  modename2:
  #    [...]
  #
  # The actions must already be defined and have default key bindings,
  # but keymap.yaml can overwrite or add to those bindings.
  def self.load_keymap
    base_dir   = File.join(ENV["HOME"], ".csup")
    keymap_fn  = File.join(base_dir, "keymap.yaml")
    unless File.exists?(keymap_fn)
      return
    end
    yaml = File.open(keymap_fn) { |f| YAML.parse(f) }
    h = yaml.as_h
    h.each do |k, v|
      mode = k.as_s
      #STDERR.puts "keymap for #{mode}:"
      if mode == "global"
	keymap = Redwood.global_keymap
      else
	keymap = Redwood.keymaps["Redwood::#{mode}"]?
      end
      unless keymap
	BufferManager.flash "Error in keymap.yaml: invalid mode #{mode}"
	return
      end
      h1 = v.as_h
      h1.each do |k1, v1|
	action = k1.as_s
	#STDERR.puts "  action: #{action}"
	val1 = v1.as_a
	keys = [] of String
	val1.each {|s| keys << s.as_s}
	#STDERR.puts "  keys: #{keys}"

	# Search the keymap for the entry for the specified action.
	entry = keymap.order.find {|e| e[0] == action}
	unless entry
	  BufferManager.flash "Error in keymap.yaml: #{mode} has no action #{action}"
	  return
	end

	# Add the keys to the entry if they're not already there.
	# Then map the keys to the entry.
	keys.each do |k|
	  unless entry[2].includes?(k)
	    entry[2] << k
	  end
	  keymap.map[k] = entry
	end
      end
    end
  end

end 	# class Keymap

end	# module Redwood
