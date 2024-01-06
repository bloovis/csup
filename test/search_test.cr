require "../src/search"

module Redwood

sm = SearchManager.new(File.join(ENV["HOME"], ".csup", "searches.txt"))
SearchManager.all_searches.each do |name|
  search_string = SearchManager.search_string_for(name)
  puts "Search #{name} = #{search_string}"
end
puts "testing that names must be " + SearchManager.name_format_hint
unless SearchManager.valid_name?("joe_blow")
  puts "valid_name? returned incorrect value for 'joe_blow'!"
end
if SearchManager.valid_name?("xyzzy*2")
  puts "valid_name? returned incorrect value for 'xyzzy*2'!"
end

SearchManager.add("joeblow", "from:joeblow@example.com")
s = SearchManager.search_string_for("joeblow")
puts "Search for joeblow is #{s}"
SearchManager.edit("joeblow", "joeblow@gmail.com")
s = SearchManager.search_string_for("joeblow")
puts "Search for joeblow is #{s}"
SearchManager.rename("joeblow", "testuser")
s = SearchManager.search_string_for("testuser")
puts "Search for testuser is #{s}"

ARGV.each do |search_string|
  expand = SearchManager.expand(search_string)
  puts "Expanded '#{search_string}' to '#{expand}'"
end

SearchManager.delete("testuser")

SearchManager.save

end	# Redwood
