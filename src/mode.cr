require "./buffer"
require "./supcurses"
require "./pipe"
require "file_utils"

class Object
  def send(action : String | Symbol)
    STDERR.puts "Object can't send #{action}!"
  end
end

module Redwood

# This macro defines a send method that given a string containing the name
# of a method, calls that method.  The arguments to the macro are
# the names of the allowed methods.
macro actions(*names)
  def send(action : String, *args)
    case action
    {% for name in names %}
    when {{ name.stringify }}
      {{ name.id }}(*args)
    {% end %}
    else
      #puts "send: unknown method for #{self.class.name}.#{action}, calling superclass"
      super(action, *args)
    end
  end

  def respond_to?(action)
    found = [
      {% for name in names %}
        {{ name.stringify }},
      {% end %}
    ].index(action.to_s)
    if found
      true
    else
      super(action)
    end
  end
end

class Mode
  # In each derived class, call the mode_class macro with the names of
  # all methods that are to be bound to keys.  This creates:
  # - an "ancestors" method for the class
  # - a "send" method that invokes the named methods
  macro mode_class(*names)
    CLASSNAME = self.name
    def ancestors
      [CLASSNAME] + super
    end
    {% if names.size > 0 %}
    Redwood.actions({{*names}})
    {% end %}
  end

  # Need these dummies to allow the subclassed versions defined
  # by mode_class to be recognized.
  def send(action : String | Symbol, *args)
    #puts "Mode.send: should never get here!"
  end

  def respond_to?(action)
    return false
  end

  # Define a getter for @buffer that always returns a non-nil value,
  # so that derived classes don't always have to check for nil.
  @buffer : Buffer?
  @dummybuffer : Buffer?

  def buffer : Buffer
    if b = @buffer
      return b
    elsif b = @dummybuffer
      #STDERR.puts "Mode.buffer: reusing dummybuffer, caller #{caller[1]}"
      return b
    else
      #STDERR.puts "Mode.buffer: creating dummybuffer, caller #{caller[1]}"

      # Return a dummy buffer.  This should only happen if a mode's initialize method
      # tries to access its buffer before it has been assigned a buffer in spawn.
      b = Buffer.new(Ncurses.stdscr, self, Ncurses.cols, Ncurses.rows-1, Opts.new)
      @buffer = b
      @dummybuffer = b
      return b
    end
  end

  def buffer=(b : Buffer)
    @buffer = b
  end

  def self.register_keymap
    classname = self.name
    #STDERR.puts "register_keymap for class #{classname}, keymaps #{Redwood.keymaps.object_id}"
    if Redwood.keymaps.has_key?(classname)
      #puts "#{classname} already has a keymap"
      k = Redwood.keymaps[classname]
    else
      k = Keymap.new {}
      Redwood.keymaps[classname] = k
      #puts "Created keymap for #{classname}, map #{k.object_id}"
      yield k
    end
    k
  end

  def ancestors
    [] of String
  end

  def self.make_name(s)
    s.gsub(/.*::/, "").camel_to_hyphy
  end

  def name
    Mode.make_name(self.class.name)
  end

  def initialize
    @buffer = nil
    #puts "Mode.initialize"
  end

  def keymap
    Redwood.keymaps[self.class.name]
  end

  def killable?; true; end
  def unsaved?; false end
  def draw; end
  def focus; end
  def blur; end
  def cancel_search!; end
  def in_search?; false end
  def status; ""; end
  def resize(rows, cols); end
  def cleanup
    #STDERR.puts "Mode.cleanup"
    @buffer = nil
  end

  def resolve_input (c : String) : String | Nil
    ancestors.each do |classname|
      #STDERR.puts "Checking if #{classname} has a keymap"
      next unless Redwood.keymaps.has_key?(classname)
      #STDERR.puts "Yes, #{classname} has a keymap"
      action = BufferManager.resolve_input_with_keymap(c, Redwood.keymaps[classname])
      return action.to_s if action
    end
    nil
  end

  def handle_input(c : String) : Bool
    if action = resolve_input(c)
      send action
      true
    else
      return false
    end
  end

  def help_text : String
    used_keys = Set(String).new
    ancestors.map do |classname|
      next unless km = Redwood.keymaps[classname]?
      title = "Keybindings from #{Mode.make_name classname}"
      s = <<-EOS
#{title}
#{"-" * title.display_length}

#{km.help_text used_keys}

EOS
      used_keys = used_keys + km.keysyms
      s
    end.compact.join("\n")
  end

### helper functions

  def save_to_file(fn : String, talk=true)
    if File.exists? fn
      unless BufferManager.ask_yes_or_no "File \"#{fn}\" exists. Overwrite?"
        #info "Not overwriting #{fn}"
        return
      end
    end
    FileUtils.mkdir_p File.dirname(fn)
    begin
      File.open(fn, "w") { |f| yield f }
      BufferManager.flash "Successfully wrote #{fn}." if talk
      true
    rescue e
      m = "Error writing file: #{e.message}"
      #info m
      BufferManager.flash m
      false
    end
  end

  def pipe_to_process(command : String) : Tuple(String?, Bool)
    pipe = Pipe.new(command, [] of String, shell: true)
    output = nil
    exit_status = pipe.start do |p|
      p.transmit do |f|
        yield f
      end
      p.receive do |f|
        output = f.gets_to_end
      end
    end
    return {output, exit_status == 0}
  end

end	# class Mode

end	# module Redwood
