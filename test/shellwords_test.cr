require "../src/shellwords.cr"

module Redwood

s1 = "this is a test"
s2 = Shellwords.escape(s1)
puts "#{s1} => #{s2}"
a1 = ["this is", "a test"]
s2 = Shellwords.join(a1)
puts "#{a1} => #{s2}"
s3 = Shellwords.join(ARGV)
puts "ARGV => #{s3}"

end
