require "../src/search"

module Redwood

sm = SearchManager.new(File.join(ENV["HOME"], ".csup", "searches.txt"))
SearchManager.all_searches.each do |name|
  search_string = SearchManager.search_string_for(name)
  puts "Search #{name} = #{search_string}"
end

end	# Redwood
