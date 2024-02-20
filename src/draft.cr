require "./singleton"
require "./notmuch"

module Redwood

class DraftManager
  singleton_class

  property folder = ""

  def initialize(folder : String)
    singleton_pre_init
    @folder = folder
    singleton_post_init
  end

  def self.write_draft(message_id : String, &block : IO -> _) # caller makes sure content has message_id
    if message_id =~ /^<(.*)>/
      message_id = $1
    end
    raise "message id is required" if message_id.size == 0

    # Delete the file with a same message_id
    delete_message_files message_id

    # Add the new message.
    Notmuch.insert(instance.folder, &block)

    m : Message? = nil
    if (ts = ThreadList.new("id:#{message_id}", offset: 0, limit: 1, body: false)) &&
       (thread = ts.threads[0]?)
      thread.each do |msg, depth, parent|
        if msg.id == message_id
	  m = msg
	end
      end
    end
    if m
      m.add_label :draft
      m.sync_back_labels
      UpdateManager.relay self, :updated, thread
    else
      raise "Cannot find draft message #{message_id}"
    end
  end

  def self.discard(m : Message)
    raise ArgumentError.new("message #{m.id} is not a draft") unless m.is_draft?
    if thread = m.thread
      delete_message_files m.id
      #STDERR.puts "DraftManager.discard deleted files for #{m.id}, calling relay :deleted"
      UpdateManager.relay self, :deleted, m
    end
  end

  def self.delete_message_files(mid : String, sync = true)
    filenames = Notmuch.filenames_from_message_id(mid)
    if filenames.size > 0
      filenames.each do |f|
        #STDERR.puts "Deleting draft file #{f}"
	debug "Deleting draft file #{f}"
	File.delete?(f)
      end
      Redwood.poll if sync
    end
  end
end

end
