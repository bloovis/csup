require "./edit_message_mode"

module Redwood

class ResumeMode < EditMessageMode
  property safe = false

  def initialize(m : Message)
    begin
      @safe = false

      # Don't parse the file directly, since it's already a Message object
      # that has been loaded from notmuch.  Steps required:
      # - Save the message of the passed-in message
      # - Call thread.load_body for the containing thread.  This will reload
      #   the messages for the thread, so the passed-in one will no longer be valid.
      # - Walk the message tree of the containing thread, and find the one
      #   that matches the ID saved in the first step
      # - Scan the message parts to find the one with the plain text body.
      # - Construct a HeaderHash from the message.
      STDERR.puts "ResumeMode.initialize about to parse #{m.draft_filename}"
      header, body = parse_file m.draft_filename
      header.delete "Date"

      super Opts.new({:header => header, :body => body, :have_signature => true})
    rescue ex
      STDERR.puts "ResumeMode.initialize exception #{ex.message}"
      BufferManager.flash "Draft deleted outside of sup: #{ex.message}"
      DraftManager.discard m
    end
    @m = m
    STDERR.puts "ResumeMode.initialize returning"
  end

  def unsaved?; !@safe end

  def killable?
    #return false if warn_editing
    return true if @safe

    case BufferManager.ask_yes_or_no "Discard draft?"
    when true
      DraftManager.discard @m
      BufferManager.flash "Draft discarded."
      true
    when false
      if edited?
        DraftManager.write_draft(@m.id) { |f| write_message f, false }
        DraftManager.discard @m
        BufferManager.flash "Draft saved."
      end
      true
    else
      false
    end
  end

  def send_message
    #STDERR.puts "ResumeMode calling EditMessageMode.send_message"
    if super
      #STDERR.puts "ResumeMode: EditMessageMode.send_message returned true"
      DraftManager.discard @m
      @safe = true
    end
  end

  def save_as_draft
    @safe = true
    super
  end
end

end
