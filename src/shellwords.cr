module Redwood

# This is a partial port of Ruby's shellwords.rb
module Shellwords
  extend self

  # Escapes a string so that it can be safely used in a Bourne shell
  # command line.
  #
  # Note that a resulted string should be used unquoted and is not
  # intended for use in double quotes nor in single quotes.
  #
  #   argv = Shellwords.escape("It's better to give than to receive")
  #   argv #=> "It\\'s\\ better\\ to\\ give\\ than\\ to\\ receive"
  #
  # It is the caller's responsibility to encode the string in the right
  # encoding for the shell environment where this string is used.
  #
  # Multibyte characters are treated as multibyte characters, not as bytes.
  #
  # Returns an empty quoted String if +str+ has a length of zero.

  def escape(str : String)
    # An empty argument will be skipped, so return empty quotes.
    return "''" if str.empty?

    # Treat multibyte characters as is.  It is the caller's responsibility
    # to encode the string in the right encoding for the shell
    # environment.
    # A LF cannot be escaped with a backslash because a backslash + LF
    # combo is regarded as a line continuation and simply ignored.
    return str.gsub(/([^A-Za-z0-9_\-.,:\/@\n])/, "\\\\\\1").gsub(/\n/, "'\n'")
  end

  # Builds a command line string from an argument list, +array+.
  #
  # All elements are joined into a single string with fields separated by a
  # space, where each element is escaped for the Bourne shell and stringified
  # using +to_s+.
  #
  #   ary = ["There's", "a", "time", "and", "place", "for", "everything"]
  #   argv = Shellwords.join(ary)
  #   argv #=> "There\\'s a time and place for everything"
  #

  def join(array : Array(String)) : String
    array.map { |arg| self.escape(arg) }.join(' ')
  end

end	# Shellwords

end	# Redwood
