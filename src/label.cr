# Similar to LabelManager in Sup, except that labels are stored
# as Strings, and label collections are Set(String).

require "./singleton"

module Redwood

class LabelManager
  singleton_class

  ## labels that have special semantics. user will be unable to
  ## add/remove these via normal label mechanisms.
  RESERVED_LABELS = Set.new([ :starred, :spam, :draft, :unread, :killed,
			      :sent, :deleted, :inbox, :attachment, :forwarded,
			      :replied ].map(&.to_s))

  ## labels that will typically be hidden from the user
  HIDDEN_RESERVED_LABELS = Set.new([ :starred, :unread, :attachment, :forwarded,
				     :replied ].map(&.to_s))

  @labels = Set(String).new
  @new_labels = Set(String).new

  def initialize(fn : String)
    singleton_pre_init

    @fn = fn
    if File.exists? fn
      File.each_line(fn) {|l| @labels << l.chomp}
    end
    @modified = false

    singleton_post_init
  end

  def new_label?(l : String | Symbol)
    @new_labels.includes?(l.to_s)
  end
  singleton_method new_label?, l

  ## all labels user-defined and system, ordered
  ## nicely and converted to pretty strings. use #label_for to recover
  ## the original label.
  def all_labels
    ## uniq's only necessary here because of certain upgrade issues
    RESERVED_LABELS + @labels
  end
  singleton_method all_labels

  ## all user-defined labels, ordered
  ## nicely and converted to pretty strings. use #label_for to recover
  ## the original label.
  def user_defined_labels
    @labels
  end
  singleton_method user_defined_labels

  ## reverse the label->string mapping, for convenience!
  def string_for(l : String | Symbol)
    ls = l.to_s
    if RESERVED_LABELS.includes? ls
      ls.capitalize
    else
      ls
    end
  end
  singleton_method string_for

  def label_for(s : String)
    raise "Cannot use LabelManager.label_for in csup!"
{% if false %}
    l = s.intern
    l2 = s.downcase.intern
    if RESERVED_LABELS.include? l2
      l2
    else
      l
    end
{% end %}
  end

  def << (t : String | Symbol)
    ts = t.to_s
    unless @labels.includes?(ts) || RESERVED_LABELS.includes?(ts)
      @labels << ts
      @new_labels << ts
      @modified = true
    end
  end
  def self.<<(t)
    self.instance.<< t
  end

  def delete(t : String | Symbol)
    ts = t.to_s
    if @labels.delete(ts)
      @modified = true
    end
  end

  def save
    return unless @modified
    fn = @fn
    if fn
      File.open(fn, "w") do |f|
        @labels.to_a.sort.each {|l| f.puts l}
      end
      @new_labels = Set(String).new
    end
  end
  singleton_method save
end

end
