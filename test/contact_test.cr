require "../src/csup"

module Redwood

init_managers

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

ARGV.each do |name|
  p = ContactManager.person_for(name)
  if p
    puts "Person for email #{name} = '#{p.to_s}'"
    isa = ContactManager.is_aliased_contact?(p)
    puts "is_aliased_contact for '#{p.to_s}' = #{isa}"
  else
    puts "No person defined for #{name}!"
  end
end

p = Person.new("Joe Blow", "joeblow@example.com")
puts "New person = '#{p.to_s}'"
if ContactManager.contact_for("joeblow")
  puts "joeblow is already a contact alias"
else
  puts "adding joeblow as alias"
  ContactManager.update_alias(p, "joeblow")
end
ContactManager.save
puts "Saved contacts_file"

end	# Redwood
