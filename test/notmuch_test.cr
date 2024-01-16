require "../src/notmuch"

module Redwood

inbox_count = Notmuch.count("tag:inbox")
puts "inbox count = #{inbox_count}"
threads = Notmuch.search("tag:inbox and date:2023-10-03")
puts "threads for yesterday = '#{threads}'"
json = Notmuch.show("tag:inbox and date:yesterday")
puts "JSON for yesterday: '#{json}'"
# The following code takes several seconds.
# addrs = Notmuch.address(["--output=sender", "from:marka@pobox.com or to:marka@pobox.com"])
# puts "addresses from or to marka@pobox.com:"
# addrs.each { |addr| puts "  #{addr.to_s}" }
lm = Notmuch.lastmod
puts "notmuch lastmod = #{lm}"
msgid1 = "242CB392-E8B6-47CA-B7BB-F791BCBC2911@gmail.com"
msgid2 = "111E9314-98B1-440F-8A6C-1B89257EAC0C@gmail.com"
tagoutput = Notmuch.tag_batch([{"id:#{msgid1}", ["joan"]},
                               {"id:#{msgid2}", ["joan"]}])
puts "tag batch output: #{tagoutput}"
filename = Notmuch.filenames_from_message_id(msgid1)
puts "filename: #{filename}"
threadid = Notmuch.thread_id_from_message_id(msgid1)
puts "threadid: #{threadid}"
tags = Notmuch.tags_from_message_id(msgid1)
puts "tags: #{tags}"

end	# Redwood
