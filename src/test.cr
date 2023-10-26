require "./index.cr"
require "./unicode.cr"
require "./util.cr"
require "./person.cr"
require "./contact.cr"
require "./shellwords.cr"
require "./rmail/address.cr"

def start_test(str : String)
  l = "-" * str.size
  puts l
  puts str
  puts l
end

start_test("Notmuch tests")
inbox_count = Notmuch.count(["tag:inbox"])
puts "inbox count = #{inbox_count}"
threads = Notmuch.search(["tag:inbox and date:yesterday"])
puts "threads for yesterday = '#{threads}'"
json = Notmuch.show(["tag:inbox and date:yesterday"])
puts "JSON for yesterday: '#{json}'"
# The following code takes several seconds.
# addrs = Notmuch.address(["--output=sender", "from:marka@pobox.com or to:marka@pobox.com"])
# puts "addresses from or to marka@pobox.com:"
# addrs.each { |addr| puts "  #{addr.to_s}" }
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

start_test("Unicode tests")
LibNCurses.setlocale(0, "")
s = "this is a test"
puts "display width of '#{s}' = #{Unicode.width(s)}"
s = "你好"
puts "display width of '#{s}' = #{Unicode.width(s)}"

start_test("String tests")
s = "this is a test"
puts "display width of '#{s}' = #{s.display_length}"
s = "你好"
puts "display width of '#{s}' = #{s.display_length}"

start_test("Person tests")
p = Person.new("Mark Alexander", "marka@pobox.com")
puts "Person = '#{p.to_s}'"
p = Person.new(nil, "noname@pobox.com")
puts "Person = '#{p.to_s}'"
p = Person.from_address("marka@pobox.com")
puts "Person = '#{p.to_s}'"
p = Person.from_address("\"A real somebody!\" <somebody@pobox.com>")
puts "Person = '#{p.to_s}'"

start_test("Contact tests")
ContactManager.init("/tmp/contacts.txt")
ContactManager.contacts.each do |p|
  puts "Contact person = '#{p.to_s}'"
end
ContactManager.contacts_with_aliases.each do |p|
  puts "Contact person with alias = '#{p.to_s}'"
end
p = ContactManager.contact_for("self")
puts "Person for alias self = '#{p.to_s}'"
al = ContactManager.alias_for(p)
puts "Alias for '#{p.to_s}' = #{al}"
p = ContactManager.person_for("marka@pobox.com")
puts "Person for email marka@pobox.com = '#{p.to_s}'"
isa = ContactManager.is_aliased_contact?(p)
puts "is_aliased_contact for '#{p.to_s}' = #{isa}"
p = Person.new("Joe Blow", "joeblow@example.com")
puts "New person = '#{p.to_s}'"
if ContactManager.contact_for("joeblow")
  puts "joeblow is already a contact alias"
else
  puts "adding joeblow as alias"
  ContactManager.update_alias(p, "joeblow")
end
ContactManager.save
puts "Saved /tmp/contacts.txt"

start_test("Shellwords tests")
s1 = "this is a test"
s2 = Shellwords.escape(s1)
puts "#{s1} => #{s2}"
a1 = ["this is", "a test"]
s2 = Shellwords.join(a1)
puts "#{a1} => #{s2}"

start_test("RMail::Address tests")
test_addresses = ["A Group:a@b.c,d@e.f;", "Mark Alexander <marka@pobox.com> (Some User)"]
test_addresses.each do |addr|
  puts "Parsing #{addr}"
  parser = RMail::Address::Parser.new(addr)
  addrs = parser.parse
  addrs.each do |a|
    puts ">>addr: #{a.address}"
    puts "  local: #{a.local}"
    puts "  name: #{a.name}"
    puts "  display name: #{a.display_name}"
    puts "  domain: #{a.domain}"
    puts "  format: #{a.format}"
    puts "  comments: #{a.comments}"
  end
end
