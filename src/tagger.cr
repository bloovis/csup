#require 'sup/util/ncurses'
require "./mode"

module Redwood

class Tagger(T)

  def initialize(noun="object", plural_noun=nil)
    @tagged = Hash(T, Bool).new
    @noun = noun
    @plural_noun = plural_noun || (@noun + "s")
  end

  def setmode(mode : Mode)
    @mode = mode
  end

  def tagged?(o : T) : Bool
    if @tagged.has_key?(o)
      @tagged[o]
    else
      false
    end
  end

  def toggle_tag_for(o : T)
    @tagged[o] = !tagged?(o)
  end

  def tag(o : T)
    @tagged[o] = true
  end

  def untag(o : T)
    @tagged[o] = false
  end

  def drop_all_tags
    @tagged.clear
  end

  def drop_tag_for(o : T)
    @tagged.delete(o)
  end


  # Return number of tagged objects.
  def num_tagged
    count = 0
    @tagged.each {|k,v| count += 1 if v == true}
    return count
  end

  # Return an array of all tagged objects.
  def all : Array(T)
    @tagged.select {|k,v| v == true}.map {|x| x.first}
  end

  # Can't implement this in Crystal even with a Proc, because
  # it constructs a method name at runtime.
  def apply_to_tagged(action=nil)
    mode = @mode
    return unless mode
    if num_tagged == 0
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
      if mode.respond_to? tagged_sym
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
