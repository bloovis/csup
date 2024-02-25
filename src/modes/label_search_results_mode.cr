require "./thread_index_mode"

module Redwood

class LabelSearchResultsMode < ThreadIndexMode
  mode_class refine_search

  def initialize(labels : Array(String))
    @labels = labels
    query = labels.map {|l| "label:#{l}"}.join(" or ")
    super query
  end

  register_keymap do |k|
    k.add :refine_search, "Refine search", '|'
  end

  def refine_search(*args)
    label_query = @labels.map {|l| "label:#{l}"}.join(" or ")
    query = BufferManager.ask :search, "refine query: ", label_query
    return unless query && query !~ /^\s*$/
    SearchResultsMode.spawn_from_query query
  end

  def self.spawn_nicely(label : String)
    #label = LabelManager.label_for(label) unless label.is_a?(Symbol)
    case label
    when "inbox"
      if instance = InboxMode.instance
	BufferManager.raise_to_front instance.buffer
      end
    else
      b, new = BufferManager.spawn_unless_exists("All threads with label '#{label}'") { LabelSearchResultsMode.new([label]) }
      #b.mode.load_threads :num => b.content_height if new
    end
  end
end

end
