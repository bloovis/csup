# Utility functions that lie outside the Redwood namespace,
# mostly extensions to standard classes.

require "../lib/ncurses/src/ncurses"
require "../lib/uniwidth/src/uniwidth"
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

# These should be replaced by Logger functions.

def warn(s : String)
  puts "warning: #{s}"
end

def debug(s : String)
  puts "debug: #{s}"
end

# String extensions

class String
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
end
