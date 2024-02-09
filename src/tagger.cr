# This implementation of Tagger differs from the one in Sup in these ways:
# - It is a generic type, and you have to specify the type of the object
#   being tagged when creating it, e.g., Tagger(Message).new, and new
#   takes no parameters.
# - It can only be used by Mode subclasses.
# - After you create the Tagger instance, you must call #setmode.
# - Mode multi_{type} methods don't take parameters; instead, they
#   must call #all to obtain an array of tagged objects.
#
# See test/tagger_test.cr for a simple example.

#require 'sup/util/ncurses'
require "./mode"

module Redwood

class Tagger(T)

  def initialize(noun="object", plural_noun=nil)
    @tagged = Set(T).new
    @noun = noun
    @plural_noun = plural_noun || (@noun + "s")
  end

  def setmode(mode : Mode)
    @mode = mode
  end

  def tagged?(o : T) : Bool
    @tagged.includes?(o)
  end

  def toggle_tag_for(o : T)
    if @tagged.includes?(o)
      @tagged.delete(o)
    else
      @tagged.add(o)
    end
  end

  def tag(o : T)
    @tagged.add(o)
  end

  def untag(o : T)
    @tagged.delete(o)
  end

  def drop_all_tags
    @tagged.clear
  end

  def drop_tag_for(o : T)
    @tagged.delete(o)
  end

  # Return number of tagged objects.
  def num_tagged
    @tagged.size
  end

  # Return an array of all tagged objects.
  def all : Array(T)
    @tagged.to_a
  end

  # Call mode.multi_{action} for each tagged object.   In Ruby
  # this works by constructing a method name at runtime and passing it
  # the list of tagged objects via `send`.  Crystal doesn't have `send`,
  # so this depends on the use of the `mode_class` macro in the relevant
  # Mode, which creates a fake `send` for a specified set of methods.
  # Also, the invoked multi_{action} method must call Tagger(T).all
  # to obtain the tagged objects.
  def apply_to_tagged(action=nil)
    STDERR.puts "apply_to_tagged, mode = #{@mode.object_id}"
    mode = @mode
    return unless mode
    if num_tagged == 0
      #STDERR.puts "apply_to_tagged: no tagged threads"
      BufferManager.flash "No tagged threads!"
      return
    end

    noun = num_tagged == 1 ? @noun : @plural_noun

    unless action
      c = BufferManager.ask_getch "apply to #{num_tagged} tagged #{noun}:"
      return if c.empty? # user cancelled
      action = mode.resolve_input c
    end

    if action
      tagged_sym = "multi_" + action.to_s
      #STDERR.puts "checking if we can send #{tagged_sym} to #{mode.class.name}"
      if mode.respond_to? tagged_sym
	#STDERR.puts "sending #{tagged_sym} to #{mode.class.name}"
        mode.send tagged_sym	# method must fetch targets using Tagger.all
      else
        BufferManager.flash "That command cannot be applied to multiple #{@plural_noun}."
      end
    else
      BufferManager.flash "Unknown command #{c}."
    end
  end
  
end

end
