require "./edit_message_mode"

module Redwood

class ForwardMode < EditMessageMode
  mode_class

  property m : Message?

  ## TODO: share some of this with reply-mode
  def initialize(opts=Opts.new)
    header = HeaderHash.new
    if acct = AccountManager.default_account
      header["From"] = acct.full_address
    end

    m = opts.message(:message)
    @m = m
    atts = opts.strarray(:attachments)
    header["Subject"] =
      if m
        "Fwd: " + m.subj
      elsif atts
        filenames = Array(String).new
	atts.each do |a|
	  filenames << a.split("|")[1]
	end
        "Fwd: " + filenames.join(", ")
      else
	"Fwd: no subject"
      end

    if to = opts.strarray(:to)
      header["To"] = to
    end
    if cc = opts.strarray(:cc)
      header["Cc"] = cc
    end
    if bcc = opts.strarray(:bcc)
      header["Bcc"] = bcc
    end

    body =
      if m
        forward_body_lines m
      elsif atts = opts.strarray(:attachments)
        ["Note: #{atts.size.pluralize "attachment"}."]
      else
	[""]
      end
    attachments = atts || [] of String
    super(Opts.new({:header => header, :body => body, :attachments => attachments}))
  end

  def self.spawn_nicely(opts = Opts.new)
    newopts = Opts.new
    unless to = opts.strarray(:to)
      if Config.bool(:ask_for_to)
        to = BufferManager.ask_for_contacts(:people, "To: ")
      end
    end
    return unless to
    newopts[:to] = to

    if Config.bool(:ask_for_cc)
      # opts[:cc] is never used.
      cc = BufferManager.ask_for_contacts(:people, "Cc: ")
    end
    newopts[:cc] = cc || [""]

    if Config.bool(:ask_for_bcc)
      # opts[:bcc] is never used.
      return unless bcc = BufferManager.ask_for_contacts(:people, "Bcc: ")
    end
    newopts[:bcc] = bcc || [""]

    attachments = opts.strarray(:attachments) || [] of String
    newopts[:attachments] = attachments

    if m = opts.message(:message)
      newopts[:message] = m
      if thread = m.thread
	thread.load_body # read the full message in. you know, maybe i should just make Message#chunks do this....
      end
      m.parts.each do |p|
        if p.content_type != "text/plain"
	  attachments << "part|#{p.filename}|#{m.id}|#{p.id}|#{p.content_type}|#{p.content_size}"
	end
      end
    end

    mode = ForwardMode.new(newopts)

    title = "Forwarding " +
      if m = opts.message(:message)
        m.subj
      elsif attachments
        filenames = Array(String).new
	attachments.each do |a|
	  filenames << a.split("|")[1]
	end
        filenames.join(", ")
      else
        "something"
      end

    BufferManager.spawn title, mode
    mode.default_edit_message
  end

  def forward_body_lines(m : Message) : Array(String)
    #attribution = HookManager.run("forward-attribution", :message => m) || default_attribution(m)
    attribution = default_attribution(m)
    attribution[0,1] +
    m.quotable_header_lines +
    [""] +
    m.quotable_body_lines +
    attribution[1,1]
  end

  protected def default_attribution(m : Message) : Array(String)
    ["--- Begin forwarded message from #{m.from.mediumname} ---",
     "--- End forwarded message ---"]
  end

  protected def send_message
    return unless super # super returns true if the mail has been sent
    if m = @m
      m.add_label :forwarded
      m.sync_back_labels
      #Index.save_message m
    end
  end
end

end
