require "benchmark"

require "../src/util"
require "../src/unicode"
require "../src/supcurses"

s = "the quick brown\nfox jumps over\nthe lazy dog.\n"
#                   15              30             44
p = s.find_all_positions("\n")
puts "Positions of newlines in '#{s}': #{p.join(",")}"

s = "this is a test"
k = "你好你好你好你好你好"

if Unicode.width(s) != UnicodeCharWidth.width(s)
  puts "Unicode and UnicodeCharWidth do not agree on '#{s}'!"
  exit 1
end
if Unicode.width(k) != UnicodeCharWidth.width(k)
  puts "Unicode and UnicodeCharWidth do not agree on '#{k}'!"
  exit 1
end

t = "The start of a big string " + s + k + s + k + " the end of the big string"
puts "Wrapping the string '#{t}' into 20-character chunks:"
w = t.wrap(20)
w.each_with_index {|x, i| puts "Chunk #{i}: '#{x}'"}

print "Now let's run some Unicode width benchmark tests.  Press Ctrl-C to abort: "
gets
Benchmark.ips do |x|
  x.report("Unicode.width of '#{s}'") { Unicode.width(s) }
  x.report("UnicodeCharWidth.width of '#{s}'") { UnicodeCharWidth.width(s) }
  x.report("String.display_length of '#{s}'") { s.display_length }
end

Benchmark.ips do |x|
  x.report("Unicode.width of '#{k}'") { Unicode.width(k) }
  x.report("UnicodeCharWidth.width of '#{k}'") { UnicodeCharWidth.width(k) }
  x.report("String.display_length of '#{k}'") { k.display_length }
end
