require "./thread_index_mode"

module Redwood

class InboxMode < ThreadIndexMode
  mode_class archive, refine_search, multi_archive, handle_unarchived_update,
	     handle_archived_update

  @@instance : InboxMode?

  register_keymap do |k|
    ## overwrite toggle_archived with archive
    k.add :archive, "Archive thread (remove from inbox)", 'a'
    k.add :refine_search, "Refine search", '|'
  end

  def initialize
    super("{inbox}", [:inbox, :sent, :draft])
    raise "can't have more than one!" if !@@instance.nil?
    @@instance = self
  end

  def refine_search(*args)
{%if false %}
    text = BufferManager.ask :search, "refine inbox with query: "
    return unless text && text !~ /^\s*$/
    text = "label:inbox -label:spam -label:deleted " + text
    SearchResultsMode.spawn_from_query text
{% else %}
    BufferManager.flash "refine_search not implemented"
{% end %}
  end

  ## label-list-mode wants to be able to raise us if the user selects
  ## the "inbox" label, so we need to keep our singletonness around
  def self.instance; @@instance; end
  def killable?; false; end

  def archive(*args)
    #STDERR.puts "inbox mode archiving thread"
    return unless thread = cursor_thread # to make sure lambda only knows about 'old' cursor_thread

    UndoManager.register "archiving thread" do
      thread.apply_label :inbox
      Notmuch.save_thread thread
      unhide_thread thread
      #reload
      update
    end

    thread.remove_label :inbox
    Notmuch.save_thread thread
    hide_thread thread
    #reload
    #regen_text
    update
  end

  def multi_archive(*args)
    #STDERR.puts "inbox mode multi_archive"
    threads = @tags.all
    UndoManager.register "archiving #{threads.size.pluralize "thread"}" do
      threads.each do |t|
        t.apply_label :inbox
        Notmuch.save_thread t
	unhide_thread t
      end
      #reload
      #regen_text
      update
    end

    threads.each do |t|
      t.remove_label :inbox
      Notmuch.save_thread t
      hide_thread t
    end
    #reload
    #regen_text
    update
  end

  def handle_unarchived_update(*args)
    if t = get_update_thread(*args)
      #STDERR.puts "inbox mode: handle_unarchived_update for #{t.id}"
      unhide_thread t
    else
      # Thread wasn't in the inbox.  Do a reload in case it should be.
      #STDERR.puts "inbox mode: handle_unarchived_update: thread not found, doing a reload"
      reload
    end
    update
  end

  def handle_archived_update(*args)
    #reload
    return unless t = get_update_thread(*args)
    hide_thread t
    update
  end

  def status
    super + "    #{Notmuch.count} messages in index"
  end
end

end
