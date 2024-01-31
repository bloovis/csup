require "./edit_message_mode"
require "../opts"
require "../account"

module Redwood

class ComposeMode < EditMessageMode
  def initialize(opts = Opts.new)
    header = Hash(String, String).new
    unless from = opts.str(:from)
      if acct = AccountManager.default_account
	from = acct.full_address
      end
    end
    return unless from
    header["From"] = from

    if to = opts.strarray(:to)
      header["To"] = to.join(", ")
    end
    if cc = opts.strarray(:cc)
      header["Cc"] = cc.join(", ")
    end
    if bcc = opts.strarray(:bcc)
      header["Bcc"] = bcc.join(", ")
    end
    if subj = opts.str(:subj)
      header["Subject"] = subj
    end
    if refs = opts.strarray(:refs)
      header["References"] = refs.map { |r| "<#{r}>" }.join(" ")
    end
    if replytos = opts.strarray(:replytos)
      header["In-Reply-To"] = replytos.map { |r| "<#{r}>" }.join(" ")
    end

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
	if acct = AccountManager.default_account
	  default_email = acct.email
	  question = "From (default #{default_email}): "
	else
	  question = "From: "
	end
       from = BufferManager.ask_for_account(:account, question)
      end
    end
    return unless from
    newopts[:to] = from

    unless to = opts.strarray(:to)
      if Config.bool(:ask_for_to)
	# FIXME - must convert list of Persons to their email addresses, and opts[:to_default]
	# must be an email address, not a person (see ThreadViewMode.compose).
        to = BufferManager.ask_for_contacts(:people, "To: ", opts.str(:to_default) || "")
      end
    end
    return unless to
    newopts[:to] = to

    if Config.bool(:ask_for_cc)
      # opts[:ccc] is never used.
      return unless cc = BufferManager.ask_for_contacts(:people, "Cc: ")
    end
    newopts[:cc] = cc if cc

    if Config.bool(:ask_for_bcc)
      # opts[:bcc] is never used.
      return unless bcc = BufferManager.ask_for_contacts(:people, "Bcc: ")
    end
    newopts[:bcc] = bcc if bcc

    if Config.bool(:ask_for_subject)
      return unless subj = (opts.str(:subj) || BufferManager.ask(:subject, "Subject: "))
    end
    newopts[:subj] = subj if subj

    mode = ComposeMode.new(newopts)
    BufferManager.spawn "New Message", mode
    mode.default_edit_message
  end
end

end
