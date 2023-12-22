#require 'sup/util/ncurses'
require "./mode"
require "./message"

module Redwood

class Tagger

  def initialize(noun="thread", plural_noun="")
    @tagged = Hash(Message, Bool).new
    @noun = noun
    @plural_noun = plural_noun || (@noun + "s")
  end

  def setmode(mode : Mode)
    @mode = mode
  end

  def tagged?(o : Message) : Bool
    if @tagged.has_key?(o)
      @tagged[o]
    else
      false
    end
  end

  def toggle_tag_for(o : Message)
    @tagged[o] = !tagged?(o)
  end

  def tag(o : Message)
    @tagged[o] = true
  end

  def untag(o : Message)
    @tagged[o] = false
  end

  def drop_all_tags
    @tagged.clear
  end

  def drop_tag_for(o : Message)
    @tagged.delete(o)
  end

{% if false %}
  # Can't implement this in Crystal even with a Proc, because
  # it constructs a method name at runtime.
  def apply_to_tagged action=nil
    targets = @tagged.select_by_value
    num_tagged = targets.size
    if num_tagged == 0
      BufferManager.flash "No tagged threads!"
      return
    end

    noun = num_tagged == 1 ? @noun : @plural_noun

    unless action
      c = BufferManager.ask_getch "apply to #{num_tagged} tagged #{noun}:"
      return if c.empty? # user cancelled
      action = @mode.resolve_input c
    end

    if action
      tagged_sym = "multi_#{action}".intern
      if @mode.respond_to? tagged_sym
        @mode.send tagged_sym, targets
      else
        BufferManager.flash "That command cannot be applied to multiple threads."
      end
    else
      BufferManager.flash "Unknown command #{c.to_character}."
    end
  end
{% end %}

  # Return an array of all tagged messages.
  def all : Array(Message)
    @tagged.select {|k,v| v == true}.map {|x| x.first}
  end
  
end

end
