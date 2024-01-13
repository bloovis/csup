require "../src/csup"
require "../src/person"

module Redwood

init_managers

p = Person.new("Mark Alexander", "marka@pobox.com")
puts "Person = '#{p.to_s}'"
p = Person.new(nil, "noname@pobox.com")
puts "Person = '#{p.to_s}'"
p = Person.from_address("marka@pobox.com")
puts "Person = '#{p.to_s}'"
p = Person.from_address("\"A real somebody!\" <somebody@pobox.com>")
puts "Person = '#{p.to_s}'"

ps = Person.from_address_list("marka@pobox.com, potus@whitehouse.gov")
ps.each do |p|
  puts "Person from list: #{p.to_s}"
end

end	# Redwood
