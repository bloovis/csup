require "./edit_message_mode"

module Redwood

class ReplyMode < EditMessageMode
  mode_class

  REPLY_TYPES = ["sender", "recipient", "list", "all", "user"]
  TYPE_DESCRIPTIONS = {
    "sender" => "Sender",
    "recipient" => "Recipient",
    "all" => "All",
    "list" => "Mailing list",
    "user" => "Customized"
  }

  property body_orig = Array(String).new

  # type_arg should be :none instead of nil.
  def initialize(message : Message, type_arg : String = nil)
    @m = message
    @edited = false

    ## it's important to put this early because it forces a read of
    ## the full headers (most importantly the list-post header, if
    ## any)
    body = reply_body_lines message
    @body_orig = body

    ## Try to find an account somewhere in the list of to's
    ## and cc's and look up the corresponding name form the list of accounts.
    ## if this does not succeed use the recipient_email (=envelope-to) instead.
    ## this is for the case where mail is received from a mailing lists (so the
    ## To: is the list id itself). if the user subscribes via a particular
    ## alias, we want to use that alias in the reply.
    if (b = (@m.to.map {|t| t.email} + @m.cc.map {|c| c.email} + [@m.recipient_email]).
             find { |p| p && AccountManager.is_account_email?(p) })
      if a = AccountManager.account_for(b)
        from = Person.new a.name, b
      end
    ## if all else fails, use the default
    else
      from = AccountManager.default_account
    end
    unless from
      BufferManager.flash "Cannot determine From:!"
      return
    end

    ## now, determine to: and cc: addressess. we ignore reply-to for list
    ## messages because it's typically set to the list address, which we
    ## explicitly treat with reply type "list"
    to = @m.is_list_message? ? @m.from : (@m.replyto || @m.from)

    ## next, cc:
    cc = (@m.to + @m.cc - [from, to]).uniq

    ## one potential reply type is "reply to recipient". this only happens
    ## in certain cases:
    ## if there's no cc, then the sender is the person you want to reply
    ## to. if it's a list message, then the list address is. otherwise,
    ## the cc contains a recipient.
    useful_recipient = !(cc.empty? || @m.is_list_message?)

    @headers = Hash(String, HeaderHash).new

    if useful_recipient
      h = HeaderHash.new
      h["To"] = cc.map { |p| p.full_address }
      h["Cc"] = Array(String).new
      @headers["recipient"] = h
    end

    ## typically we don't want to have a reply-to-sender option if the sender
    ## is a user account. however, if the cc is empty, it's a message to
    ## ourselves, so for the lack of any other options, we'll add it.
    if !AccountManager.is_account?(to) || !useful_recipient
      h = HeaderHash.new
      h["To"] = [to.full_address]
      h["Cc"] = Array(String).new
      @headers["sender"] = h
    end

    h = HeaderHash.new
    h["To"] = Array(String).new
    h["Cc"] = Array(String).new
    @headers["user"] = h

    not_me_ccs = cc.select { |p| !AccountManager.is_account?(p) }
    unless not_me_ccs.empty?
      h = HeaderHash.new
      h["To"] = [to.full_address]
      h["Cc"] = not_me_ccs.map { |p| p.full_address }
      @headers["all"] = h
    end

    if @m.is_list_message?
      h = HeaderHash.new
      h["To"] = [@m.list_address || ""]
      h["Cc"] = Array(String).new
      @headers["list"] = h
    end

    refs = gen_references

    types = REPLY_TYPES.select { |t| @headers.has_key?(t) }
    @type_selector = HorizontalSelector.new "Reply to:", types, types.map { |x| TYPE_DESCRIPTIONS[x] }

    #hook_reply = HookManager.run "reply-to", :modes => types, :message => @m

    @type_selector.set_to(
      if type_arg && types.includes?(type_arg)
        type_arg
      #elsif types.include? hook_reply
      #  hook_reply
      elsif @m.is_list_message?
        "list"
      elsif @headers.has_key? "sender"
        "sender"
      else
        "recipient"
      end)

    h = HeaderHash.new
    h["From"] = from.full_address
    h["Bcc"] = Array(String).new
    h["In-reply-to"] = "<#{@m.id}>"
    h["Subject"] = Message.reify_subj(@m.subj)
    h["References"] = refs
    headers_full = h.merge @headers[@type_selector.val]

    #HookManager.run "before-edit", :header => headers_full, :body => body

    super(Opts.new({:header => headers_full, :body => body, :twiddles => false}))
    add_selector @type_selector
  end

# protected

  # Curiously, the following methods use the idiom `self.header` to access the
  # `header` property in EditMessageMode, though `@header` would have worked as well.

  def move_cursor_right(*args)
    super
    if @headers[@type_selector.val] != self.header
      self.header = self.header.merge @headers[@type_selector.val]
      #rerun_crypto_selector_hook
      update
    end
  end

  def move_cursor_left(*args)
    super
    if @headers[@type_selector.val] != self.header
      self.header = self.header.merge @headers[@type_selector.val]
      #rerun_crypto_selector_hook
      update
    end
  end

  def reply_body_lines(m : Message) : Array(String)
    #attribution = HookManager.run("attribution", :message => m) || default_attribution(m)
    attribution = default_attribution(m)
    lines = attribution.split("\n") + m.quotable_body_lines.map { |l| "> #{l}" }
    while lines.last =~ /^\s*$/
      lines.pop
    end
    lines
  end

  def default_attribution(m : Message) : String
    "Excerpts from #{@m.from.name}'s message of #{@m.date}:"
  end

{% if false %}

  # FIXME: what is this for?
  def handle_new_text(new_header, new_body)
    if new_body != @body_orig
      @body_orig = new_body
      @edited = true
    end
    old_header = @headers[@type_selector.val]
    if old_header.any? { |k, v| new_header[k] != v }
      @type_selector.set_to "user"
      self.header["To"] = @headers["user"]["To"] = new_header["To"]
      self.header["Cc"] = @headers["user"]["Cc"] = new_header["Cc"]
      update
    end
  end

  def edit_field(field)
    edited_field = super
    if edited_field and (field == "To" or field == "Cc")
      @type_selector.set_to "user"
      @headers["user"]["To"] = self.header["To"]
      @headers["user"]["Cc"] = self.header["Cc"]
      update
    end
  end

{% end %}

  def gen_references : String
    (@m.refs + [@m.id]).map { |x| "<#{x}>" }.join(" ")
  end

  def send_message
    return unless super # super returns true if the mail has been sent
    @m.add_label :replied
    @m.sync_back_labels
    #Index.save_message @m
  end
end

end
