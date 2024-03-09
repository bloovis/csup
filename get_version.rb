#!/usr/bin/env ruby

p = IO::popen(['git', 'rev-parse', 'HEAD'])
gitver = p.read[0, 7]
p.close
File.open("version.cr", "w") do |f|
  f.puts "module Redwood"
  f.puts "VERSION = \"git-#{gitver}\""
  f.puts "end"
end

