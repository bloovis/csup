require "benchmark"

require "../src/util"
require "../src/unicode"
require "../src/supcurses"

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
