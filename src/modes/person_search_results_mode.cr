require "./thread_index_mode"
require "../person"

module Redwood

class PersonSearchResultsMode < ThreadIndexMode
  mode_class

  def initialize(people : Array(Person))
    @people = people
    query = people.map{|p| "from:#{p.email}"}.join(" or ")
    #STDERR.puts "PersonSearchResultsMode: query = '#{query}'"
    super(query)
  end
end

end
