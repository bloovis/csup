require "./index.cr"
require "./unicode.cr"
require "./util.cr"
require "./person.cr"

puts "Notmuch tests"
puts "-------------"
inbox_count = Notmuch.count(["tag:inbox"])
puts "inbox count = #{inbox_count}"
threads = Notmuch.search(["tag:inbox and date:yesterday"])
puts "threads for yesterday = '#{threads}'"
json = Notmuch.show(["tag:inbox and date:yesterday"])
puts "JSON for yesterday: '#{json}'"
addrs = Notmuch.address(["--output=sender", "from:marka@pobox.com or to:marka@pobox.com"])
puts "addresses from or to marka@pobox.com:"
addrs.each { |addr| puts "  #{addr.to_s}" }
lm = Notmuch.lastmod
puts "notmuch lastmod = #{lm}"
tagoutput = Notmuch.tag_batch([{"id:101649.65756.qm@web111507.mail.gq1.yahoo.com", ["marianne"]},
                               {"id:182504.40420.qm@web111514.mail.gq1.yahoo.com", ["marianne"]}])
puts "tag batch output: #{tagoutput}"
filename = Notmuch.filenames_from_message_id("101649.65756.qm@web111507.mail.gq1.yahoo.com")
puts "filename: #{filename}"
threadid = Notmuch.thread_id_from_message_id("101649.65756.qm@web111507.mail.gq1.yahoo.com")
puts "threadid: #{threadid}"
tags = Notmuch.tags_from_message_id("101649.65756.qm@web111507.mail.gq1.yahoo.com")
puts "tags: #{tags}"

puts "Unicode tests"
puts "-------------"
LibNCurses.setlocale(0, "")
s = "this is a test"
puts "display width of '#{s}' = #{Unicode.width(s)}"
s = "你好"
puts "display width of '#{s}' = #{Unicode.width(s)}"

puts "String tests"
puts "------------"
s = "this is a test"
puts "display width of '#{s}' = #{s.display_length}"
s = "你好"
puts "display width of '#{s}' = #{s.display_length}"

puts "Person tests"
puts "------------"
p = Person.new("Mark Alexander", "marka@pobox.com")
puts "Person = '#{p.to_s}'"
p = Person.new(nil, "noname@pobox.com")
puts "Person = '#{p.to_s}'"
p = Person.from_address("marka@pobox.com")
puts "Person = '#{p.to_s}'"
p = Person.from_address("\"A real somebody!\" <somebody@pobox.com>")
puts "Person = '#{p.to_s}'"
