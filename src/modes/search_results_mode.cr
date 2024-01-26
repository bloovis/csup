require "./thread_index_mode"

module Redwood

class SearchResultsMode < ThreadIndexMode
  mode_class refine_search, save_search

  register_keymap do |k|
    k.add :refine_search, "Refine search", '|'
    k.add :save_search, "Save search", '%'
  end

  def initialize(@query : String)
    super(query)
  end

  def refine_search(*args)
    text = BufferManager.ask :search, "refine query: ", (@query + " ")
    return unless text && !(text =~ /^\s*$/)
    SearchResultsMode.spawn_from_query text
  end

  def save_search(*args)
    name = BufferManager.ask :save_search, "Name this search: "
    return unless name && !(name =~ /^\s*$/)
    name = name.strip
    unless SearchManager.valid_name? name
      BufferManager.flash "Not saved: " + SearchManager.name_format_hint
      return
    end
    if SearchManager.all_searches.includes? name
      BufferManager.flash "Not saved: \"#{name}\" already exists"
      return
    end
    if SearchManager.add name, @query.strip
      BufferManager.flash "Search saved as \"#{name}\""
    end
  end

  ## a proper is_relevant? method requires some way of asking the index
  ## if an in-memory object satisfies a query. i'm not sure how to do
  ## that yet. in the worst case i can make an in-memory index, add
  ## the message, and search against it to see if i have > 0 results,
  ## but that seems pretty insane.

  def self.spawn_from_query(text : String)
    begin
      query = Notmuch.translate_query(text)
      return unless query
      short_text = text.length < 20 ? text : text[0 ... 20] + "..."
      mode = SearchResultsMode.new query
      BufferManager.spawn "search: \"#{short_text}\"", mode
      #mode.load_threads :num => mode.buffer.content_height
    rescue e : Notmuch::ParseError
      BufferManager.flash "Problem: #{e.message}!"
    end
  end
end

end
