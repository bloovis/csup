# Utility functions that lie outside the Redwood namespace,
# mostly extensions to standard classes.

require "./unicode"

# Exceptions

class NameError < Exception
end

class ArgumentError < Exception
end

class InputSequenceAborted < Exception
end

class StandardError < Exception
end

# String extensions

class String
  def length
    size
  end

  def display_length
    Unicode.width(self)
  end

  def slice_by_display_length(len)
    # Chop it down to the maximum allowable size before attempting to
    # get the Unicode width, because UnicodeCharWidth is VERY slow
    # on big strings.
    s = self[0, len]

    # Chop off characters on the right until the display length fits.
    while Unicode.width(s) > len
      s = s.rchop
    end
    return s
  end

  def camel_to_hyphy
    self.gsub(/([a-z])([A-Z0-9])/, "\\1-\\2").downcase
  end

  def find_all_positions(x : String) : Array(Int32)
    ret = [] of Int32
    start = 0
    while start < size
      pos = index x, start
      break if pos.nil?
      ret << pos
      start = pos + 1
    end
    ret
  end

  def wrap(len) : Array(String)
    ret = [] of String
    s = self
    while s.display_length > len
      slice = s.slice_by_display_length(len)
      cut = slice.rindex(/\s/)
      if cut
        ret << s[0 ... cut]
        s = s[(cut + 1) .. -1]
      else
        ret << slice
        s = s[slice.size .. -1]
      end
    end
    ret << s
  end

  def pad_left(width : Int32)
    pad = width - self.display_length
    " " * pad + self
  end

  def pad_right(width : Int32)
    pad = width - self.display_length
    self + " " * pad
  end

  def to_sym
    raise "Crystal doesn't support changing string '#{self}' to a symbol!"
  end

  def normalize_whitespace
    #fix_encoding!
    gsub(/\t/, "    ").gsub(/\r/, "")
  end

  ## a very complicated regex found on teh internets to split on
  ## commas, unless they occur within double quotes.
  def split_on_commas
    normalize_whitespace.split(/,\s*(?=(?:[^"]*"[^"]*")*(?![^"]*"))/)
  end

end

# Enumerable extensions

module Enumerable
  # like find, except returns the value of the block rather than the
  # element itself.
  def argfind
    ret = nil
    find { |e| ret ||= yield(e) }
    ret || nil # force
  end

  def length
    size
  end

  def member?(x)
    !index(x).nil?
  end

  def max_of
    map { |e| yield e }.max
  end
end

# Number extensions

struct Int
  def to_human_size : String
    if self < 1024
      to_s + "B"
    elsif self < (1024 * 1024)
      (self // 1024).to_s + "KiB"
    elsif self < (1024 * 1024 * 1024)
      (self // 1024 // 1024).to_s + "MiB"
    else
      (self // 1024 // 1024 // 1024).to_s + "GiB"
    end
  end

  # Definitely cheesy, but it keeps existing Sup code happy, even if
  # if it's not always correct.
  def pluralize(s : String) : String
    if self != 1
      if s =~/(.*)y$/
	"#{self} #{$1}ies"
      else
	"#{self} #{s}s"
      end
    else
      "#{self} #{s}"
    end
  end

end

## acts like a hash with an initialization block, but saves any
## newly-created value even upon lookup.
##
## for example:
##
## class C
##   property val
##   def initialize; @val = 0 end
## end
##
## h = Hash(Symbol, C).new { C.new }
## h[:a].val # => 0
## h[:a].val = 1
## h[:a].val # => 0
##
## h2 = SavingHash(Symbol, C).new { C.new }
## h2[:a].val # => 0
## h2[:a].val = 1
## h2[:a].val # => 1
##
## important note: you REALLY want to use #has_key? to test existence,
## because just checking h[anything] will always evaluate to true
## (except for degenerate constructor blocks that return nil or false)

class SavingHash(K,V) < Hash(K,V)
  def initialize(&b : K -> V)
    super
    @constructor = b
    @hash = Hash(K,V).new
  end

  def [](k : K)
    if @hash.has_key?(k)
      @hash[k]
    else
      @hash[k] = @constructor.call(k)
    end
  end

  def each(&b : K, V -> _)
    @hash.each(&b)
  end

  forward_missing_to @hash
end

# Sup expects Ruby arrays to be sparse, i.e., a value can be read or assigned
# with an index that is greater than the current array size.  This
# class simulates that behavior for the [i] and [i]= operators.

class SparseArray(T) < Array(T?)
  def [](i)
    if i >= size
      (size..i).each {|n| self.<<(nil)}
      nil
    else
      super
    end
  end

  def []=(i : Int32, v : T)
    #STDERR.puts "SparseArray [#{i}]= #{v.object_id} (#{v.class.name}), caller #{caller[1]}"
    if i >= size
      if i > 0
	(size..i-1).each {|n| self.<<(nil)}
      end
      self << v
    else
      super
    end
  end
end

# Define File.mtime for Sup compatibility

class File
  def self.mtime(fname : String) : Time
    File.info(fname).modification_time
  end
end

# Macros for defining boolean instance variables that can be accessed
# using names ending with a '?'.

macro bool_getter(*names)
  {% for name in names %}
    getter {{name.id}} : Bool
    def {{name.id}}?; {{name.id}}; end
  {% end %}
end

macro bool_property(*names)
  {% for name in names %}
    property {{name.id}} : Bool
    def {{name.id}}?; {{name.id}}; end
  {% end %}
end
