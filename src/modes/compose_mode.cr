require "./edit_message_mode"
require "../opts"
require "../account"

module Redwood

class ComposeMode < EditMessageMode
  def initialize(opts = Opts.new)
    header = Hash(String, String).new
    header["From"] = (opts.str(:from) || AccountManager.default_account).full_address

    # FIXME: These multi-address options should be String arrays, not Person arrays!
    header["To"] = opts.strarray(:to).join(", ") if opts.member?(:to)
    header["Cc"] = opts.strarray(:cc).join(", ") if opts.member?(:cc)
    header["Bcc"] = opts.strarray(:bcc).join(", ") if opts.member?(:bcc)

    header["Subject"] = opts.str(:subj) if opts.member?(:subj)
    header["References"] = opts.strarray(:refs).map { |r| "<#{r}>" }.join(" ") if opts.member?(:refs)
    header["In-Reply-To"] = opts.strarray(:replytos).map { |r| "<#{r}>" }.join(" ") if opts.member?(:replytos)

    newopts = Opts.new
    newopts[:header] = header
    newopts[:body] = opts.strarray(:body) || Array(String).new
    super newopts
  end

  def default_edit_message
    edited = super
    BufferManager.kill_buffer self.buffer unless edited
    edited
  end

  def self.spawn_nicely(opts = Opts.new)
    newopts = Opts.new

    unless from = opts.str(:from)
      if Config.bool(:ask_for_from)
        return unless from = BufferManager.ask_for_account(:account, "From (default #{AccountManager.default_account.email}): ")
      end
    end
    newopts[:to] = from

    unless to = opts.strarray(:to)
      if Config.bool(:ask_for_to)
	# FIXME - must convert list of Persons to their email addresses, and opts[:to_default]
	# must be an email address, not a person (see ThreadViewMode.compose).
        if people = BufferManager.ask_for_contacts(:people, "To: ", opts.str(:to_default) || "")
	  to = people.map {|p| p.full_address}
	else
	  return
	end
      end
    end
    newopts[:to] = to

    if Config.bool(:ask_for_cc)
      # opts[:ccc] is never used.
      return unless cc = BufferManager.ask_for_contacts(:people, "Cc: ")
    end
    newopts[:cc] = cc

    if Config.bool(:ask_for_bcc)
      # opts[:bcc] is never used.
      return unless bcc = BufferManager.ask_for_contacts(:people, "Bcc: ")
    end
    newopts[:bcc] = bcc

    if Config.bool(:ask_for_subject)
      return unless subj = (opts.str(:subj) || BufferManager.ask(:subject, "Subject: "))
    end
    newopts[:subj] = subj

    mode = ComposeMode.new(newopts)
    BufferManager.spawn "New Message", mode
    mode.default_edit_message
  end
end

end
