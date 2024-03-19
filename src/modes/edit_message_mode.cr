require "./line_cursor_mode"
require "../horizontal_selector"
require "../shellwords"
require "../rfc2047"
require "../opts"
require "../../lib/email/src/email"
require "../sent"

module Redwood

class Attachment
  # part and message_id are defined if this attachment
  # is a notmuch part.  Otherwise this is a filename attachment.
  property message_id : String?
  property part : Int32?

  property filename = ""
  property basename = ""
  property content_type = ""
  property size = 0

  # s is a string describing the attachment.  It consists
  # of '|'- separated components.  There are two types:
  # - notmuch part: part|<filename>|<message id>|<part no>|<content type>|<size>
  # - file: file|<filename>
  def initialize(s : String)
    splits = s.split("|")
    case splits[0]
    when "file"
      @filename = splits[1]
      unless File.exists?(@filename)
        raise "Attachment file #{@filename} does not exist!"
      end
      @content_type = `file -b --mime-type #{@filename}`.strip
      @size = File.size(@filename)
      @basename = Path[@filename].basename
      #STDERR.puts "Created file attachment: #{@filename}, base name #{@basename}, size #{@size}, content type #{@content_type}"
    when "part"
      @filename = splits[1]
      @message_id = splits[2]
      @part = splits[3].to_i
      @basename = @filename
      @content_type = splits[4]
      @size = splits[5].to_i
      #STDERR.puts "Created part attachment: mid #{@message_id}, part #{@part}, #{@filename}, size #{@size}, content type #{@content_type}"
    else
      raise "Invalid attachment descriptor type '#{splits[0]}'"
    end
  end

  def attach_to_email(email : EMail::Message)
    if (msgid = @message_id) && (part = @part)
      Notmuch.write_part(msgid, part) do |f|
        email.attach(f, @filename, @content_type)
      end
    else
      basename = Path[@filename].basename
      #STDERR.puts "Attaching file #{@filename}, base name #{basename}, content type #{@content_type}"
      email.attach(@filename, basename, @content_type)
    end
  end
end

class EditMessageMode < LineCursorMode
  mode_class send_message, default_edit_message, save_as_draft,
	     move_cursor_right, move_cursor_left, attach_file, delete_attachment
	     #edit_message_or_field, edit_to, edit_cc
	     #edit_subject,  alternate_edit_message,


  # HeaderHash, defined in ScrollMode, is a representation
  # of email headers that is "cooked", where headers that can
  # have multiple values (To:, CC, and Cc:) are arrays of strings,
  # not strings.
  #
  # By contrast, RawHeaderHash, defined here, is a representation
  # of email headers that is NOT "cooked", where To:, Cc:, and Bcc:
  # appear as they would in a real message, i.e., as a strings
  # consisting of multiple comma-separated addresses.
  #
  # It gets confusing in the original Sup code, because these
  # two kinds of hashes get mixed up, and it's not always clear
  # which is which.  By using these alias class names, I hope to
  # clear up some of this confusion.
  alias RawHeaderHash = Hash(String, String)

  DECORATION_LINES = 1

  FORCE_HEADERS = %w(From To Cc Bcc Subject)
  MULTI_HEADERS = %w(To Cc Bcc)
  NON_EDITABLE_HEADERS = %w(Message-ID Date)

  property body = Array(String).new
  property header = HeaderHash.new
  property text = TextLines.new
  property account_user = ""
  property email_log_set = false
  property temp_files = Array(String).new
  property attachments = Array(Attachment).new
  property attachment_lines_offset = 0

  property account_selector : HorizontalSelector?
  bool_getter edited
  property file : File?

  register_keymap do |k|
    k.add :send_message, "Send message", 'y'
    #k.add :edit_message_or_field, "Edit selected field", 'e'
    #k.add :edit_to, "Edit To:", 't'
    #k.add :edit_cc, "Edit Cc:", 'c'
    #k.add :edit_subject, "Edit Subject", 's'
    k.add :default_edit_message, "Edit message (default)", "C-m"
    #k.add :alternate_edit_message, "Edit message (alternate, asynchronously)", 'E'
    k.add :save_as_draft, "Save as draft", 'P'
    k.add :attach_file, "Attach a file", 'a'
    k.add :delete_attachment, "Delete an attachment", 'd'
    k.add :move_cursor_right, "Move selector to the right", "Right", 'l'
    k.add :move_cursor_left, "Move selector to the left", "Left", 'h'
  end

  def initialize(opts = Opts.new)
    @header = opts.delete_hash(:header) || HeaderHash.new
    @header_lines = Array(String).new

    @body = opts.delete_strarray(:body) || Array(String).new

    # In Sup, the attachments option was a hash of filename => RMail attachment.
    # In Csup, the attachments option an array of attachment descriptor strings,
    # which we use to create Attachment objects (see above).
    if atts = opts.strarray(:attachments)
      atts.each do |a|
	@attachments << Attachment.new(a)
      end
    end

    hostname = `hostname`.strip

    message_id = "#{Time.now.to_i}-csup-#{rand 10000}@#{hostname}"
    @message_id = "<#{message_id}>"
    @edited = false
    @sig_edited = false
    @selectors = Array(HorizontalSelector).new
    @selector_label_width = 0
    #@async_mode = nil

    # HookManager.run "before-edit", :header => @header, :body => @body

    # only show account selector if there is more than one email address
    if Config.bool(:account_selector) && AccountManager.user_emails.size > 1
      # In Sup, a nil value was used for Customized.  In Csup we use
      # blank string to avoid lots of compile-time nil errors.
      selector =
        HorizontalSelector.new "Account:", # label
				AccountManager.user_emails + [""], # vals
				AccountManager.user_emails + ["Customized"] #labels

      @account_selector = selector
      if @header["From"] =~ /<?(\S+@(\S+?))>?$/
        # TODO: this is ugly. might implement an AccountSelector and handle
        # special cases more transparently.
        account_from = selector.can_set_to?($1) ? $1 : nil
        selector.set_to account_from
      else
        selector.set_to ""
      end

      # A single source of truth might better than duplicating this in both
      # @account_user and @account_selector.
      @account_user = @header["From"].as(String)

      add_selector selector
    end

{% if false %}
    @crypto_selector =
      if CryptoManager.have_crypto?
        HorizontalSelector.new "Crypto:", [:none] + CryptoManager::OUTGOING_MESSAGE_OPERATIONS.keys, ["None"] + CryptoManager::OUTGOING_MESSAGE_OPERATIONS.values
      end
    add_selector @crypto_selector if @crypto_selector

    if @crypto_selector
      HookManager.run "crypto-mode", :header => @header, :body => @body, :crypto_selector => @crypto_selector
    end
{% end %}
    super opts
    regen_text
  end

  # Return a new hash whose entries are those in h, but excluding any entries
  # whose keys in the array a.  This is used to delete non-editable headers from @headers.
  def purge_hash(h, a : Array(String))
    newh = h.clone
    a.each {|key| newh.delete(key) }
    return newh
  end

  def move_cursor_left(*args)
    if @curpos < @selectors.length
      @selectors[@curpos].roll_left
      buffer.mark_dirty
      update if @account_selector
    else
      col_left
    end
  end

  def move_cursor_right(*args)
    if @curpos < @selectors.length
      @selectors[@curpos].roll_right
      buffer.mark_dirty
      update if @account_selector
    else
      col_right
    end
  end

  def add_selector(s : HorizontalSelector)
    @selectors << s
    @selector_label_width = [@selector_label_width, s.label.size].max
  end

  def update
    #STDERR.puts "update: about to examine account_selector"
    #STDERR.puts "update: account_selector = #{@account_selector}"
    if a = @account_selector
      #STDERR.puts "update: a.val = #{a.val}"
      if a.val == ""
        @header["From"] = @account_user
      else
        @header["From"] = AccountManager.full_address_for(a.val).as(String)
      end
    end

    regen_text
    buffer.mark_dirty if buffer
  end

  def regen_text
    @text = TextLines.new
    header, @header_lines = format_headers(purge_hash(@header, NON_EDITABLE_HEADERS)) # + [""] <-- what is this?
    #@text = header + [""] + @body
    header.each do |l|
      #STDERR.puts "regen_text: adding line '#{l}'"
      @text << l
    end
    @text << ""
    @body.each {|l| @text << l}
    if !@sig_edited
      sig_lines.each {|l| @text << l}
    end

    @attachment_lines_offset = 0

    if (attachments = @attachments) && (attachments.size > 0)
      @text << ""
      @attachment_lines_offset = @text.size
      attachments.each do |a|
        @text << [{:attachment_color, "+ Attachment: #{a.filename} (#{a.size.to_human_size})"}]
      end
    end
  end

  def parse_raw_email_header(f : File) : RawHeaderHash
    header = RawHeaderHash.new
    last = nil

    while(line = f.gets)
      case line
      ## these three can occur multiple times, and we want the first one
      when /^(Delivered-To|X-Original-To|Envelope-To):\s*(.*?)\s*$/i; header[last = $1.capitalize] ||= $2
      ## regular header: overwrite (not that we should see more than one)
      ## TODO: figure out whether just using the first occurrence changes
      ## anything (which would simplify the logic slightly)
      when /^([^:\s]+):\s*(.*?)\s*$/i; header[last = $1.capitalize] = $2
      when /^\r*$/; break # blank line signifies end of header
      else
        if last
	  h = header[last]
	  h += " " unless header[last].size == 0
	  h += line.strip
          header[last] = h
        end
      end
    end

    %w(subject from to cc bcc).each do |k|
      next unless v = header[k]?
      next unless Rfc2047.is_encoded? v
      header[k] = begin
        Rfc2047.decode_to "UTF-8", v
      rescue e
        STDERR.puts "warning: error decoding RFC 2047 header (e.message})"
        v
      end
    end
    header
  end

  # Read an email file and break it into two parts: a "cooked" representation
  # of its headers (i.e., a HeaderHash), and the body of the the email
  # as an array of strings (one for each line).
  def parse_file(fn : String) : Tuple(HeaderHash, Array(String))
    header = HeaderHash.new
    body = Array(String).new
    File.open(fn) do |f|
      raw_headers = parse_raw_email_header(f)
      f.each_line { |l| body << l.chomp }

      raw_headers.each do |k, v|
        if !NON_EDITABLE_HEADERS.member? k
	  header[k] = parse_header k, v
	end
      end
    end
    return {header, body}
  end

  # Parse a "raw" email header and "cook" it into something that
  # can be stored in a HeaderHash. "Cooking" means changing a header
  # that can have multiple addresses (To:, Cc:, Bcc:) into an
  # array of email addresses.  All other headers remain unchanged.
  def parse_header(k : String, v : String) : String | Array(String)
    if MULTI_HEADERS.includes?(k)
      result = Array(String).new
      v.as(String).split_on_commas.each do |name|
        if p = ContactManager.contact_for(name)
	  result << p.full_address
	else
	  result << name
	end
      end
      return result
    else
      return v.as(String)
    end
  end


  def format_headers(header : HeaderHash) : Tuple(TextLines, Array(String))
    header_lines = Array(String).new	# array of header keys
    headers = TextLines.new
    (FORCE_HEADERS + (header.keys - FORCE_HEADERS)).each do |h|
      lines = make_lines "#{h}:", header[h]? || ""
      lines.each do |l|
        #STDERR.puts "format_headers: adding line #{l} to headers"
        header_lines << h
	headers << l
      end
    end
    return {headers, header_lines}
  end

  def make_lines(header : String, things : String | Array(String)) : Array(String)
    if things.is_a?(String)
      #STDERR.puts "make_lines: string for #{header} = #{things}"
      return [header + " " + things]
    else
      if things.size == 0
        return [header]
      else
	lines = Array(String).new
        things.each_with_index do |name, i|
          #raise "an array: #{name.inspect} (things #{things.inspect})" if Array === name
          #STDERR.puts "make_lines: header #{header}, name[#{i}] = #{name}"
          if i == 0
            line =  header + " " + name
          else
            line = (" " * (header.display_length + 1)) + name
	  end
          line += (i == things.length - 1 ? "" : ",")
	  lines << line
        end
	return lines
      end
    end
  end

  # Edit an email message.  Return true if the user changed it.
  def default_edit_message(*args) : Bool
    # FIXME: will we every support async edit?  Maybe not.
    #if $config[:always_edit_async]
    #  return edit_message_async
    #else
      edited = edit_message
      return edited
    #end
  end

  def handle_new_text(header, body); end

  def lines; @text.length + selector_lines end

  def [](i : Int32) : Text
    if @editing && i == 0
      return [{:editing_notification_color, " [read-only] Message being edited in an external editor"}]
    end
    if @selectors.size == 0
      return decorate_editing_line @text[i]
    elsif i < @selectors.size
      return @selectors[i].line @selector_label_width
    elsif i == @selectors.size
      return ""
    else
      return decorate_editing_line @text[i - @selectors.length - DECORATION_LINES]
    end
  end

  def decorate_editing_line(line) : Text
    if @editing && line.is_a?(String)
      [{:editing_frozen_text_color, line}]
    else
      line
    end
  end

  def selector_lines
    lines = (@selectors.empty? ? 0 : DECORATION_LINES + @selectors.size)
  end

  # Edit an email message.  Return true if the user changed it.
  def edit_message
    # Probably only need this if async editing isn't supported.
    #return false if warn_editing

    if  @account_selector
      old_from = @header["From"].as(String)
    end
    old_from ||= ""

    begin
      save_message_to_file
    rescue e
      BufferManager.flash "Can't save message to file: #{e.message}"
      return false
    end

    # prepare command line arguments
    editor = Config.str(:editor) || ENV["EDITOR"] || "/usr/bin/vi"

    return false unless file = @file
    filepath = file.path
    pos = [@curpos - selector_lines, @header_lines.size].max + 1
    ENV["LINE"] = pos.to_s
    ENV["FILE"] = filepath
    command = editor.gsub(/\$LINE\b/, pos.to_s)
    command = command + " $FILE" unless command.includes?("$FILE")
    command = command.gsub(/\$FILE\b/, Shellwords.escape(filepath))
    start_edit command, filepath, false, old_from	# false was is_gui
  end

  def killable?
{% if false %}
    return false if warn_editing
    if !@async_mode.nil?
      return false if !@async_mode.killable?
      if File.mtime(@file.path) > @mtime
        @edited = true
        header, @body = parse_file @file.path
        @header = header - NON_EDITABLE_HEADERS
        handle_new_text @header, @body
        update
      end
    end
{% end %}
    ok = !edited? || BufferManager.ask_yes_or_no("Discard message?")
    #STDERR.puts "EditMessageMode: killable? = #{ok}"
    return ok
  end

  # Remove all temporary files.  BufferManager calls when it's deleting the mode's buffer.
  def cleanup
    @temp_files.each do |path|
      #STDERR.puts "deleting temp file #{path}"
      File.delete?(path)
    end
    @temp_files = Array(String).new
    super
  end

  def save_message_to_file
    #raise 'cannot save message to another file while editing' if @editing
    sig = sig_lines.join("\n")
    file = File.tempfile("csup.#{self.class.name.gsub(/.*::/, "").camel_to_hyphy}.eml")
    @file = file
    @temp_files << file.path
    #STDERR.puts "created temp file #{file.path}"
    #STDERR.puts "About to call format_headers with header #{@header}"
    headers = format_headers(purge_hash(@header, NON_EDITABLE_HEADERS))[0]
    #STDERR.puts "format_headers returned headers #{headers}"
    headers.each {|l| file.puts l}
    #file.puts
    file.puts

    text = @body.join("\n")
    file.puts text
    file.puts sig if (Config.bool(:edit_signature) && !@sig_edited)
    file.close
  end

  def mentions_attachments?
    #if HookManager.enabled? "mentions-attachments"
    #  HookManager.run "mentions-attachments", :header => @header, :body => @body
    #else
      @body.any? {  |l| l =~ /^[^>]/ && l =~ /\battach(ment|ed|ing|)\b/i }
    #end
  end

  def top_posting?
    # The + "\n" ensures that the last line terminates with a \n.
    @body.join("\n") + "\n" =~ /(\S+)\s*Excerpts from.*\n(>.*\n)+\s*\Z/
  end

  def sig_lines : Array(String)
    lines = Array(String).new

    if p = Person.from_address(@header["From"].as(String))
      from_email = p.email
    end

    ## first run the hook
    hook_sig : String? = nil
    success = HookManager.run("signature") do |pipe|
      pipe.receive do |f|
        hook_sig = f.gets_to_end
      end
    end
    if success && hook_sig
      lines << ""
      lines << "-- "
      hook_sig.each_line {|l| lines << l}
      return lines
    end

    ## no hook, do default signature generation based on config.yaml
    return lines unless from_email
    acct = AccountManager.account_for(from_email) || AccountManager.default_account
    if acct && (sigfn = acct.signature) && File.exists?(sigfn)
      lines << ""
      lines << "-- "
      File.read_lines(sigfn).each {|l| lines << l.chomp }
    end
    return lines
  end

  def attach_file(*args)
    fn = BufferManager.ask_for_filename :attachment, "File name (enter for browser): "
    return unless fn
    begin
      Dir[fn].each do |f|
        @attachments << Attachment.new("file|#{f}")
      end
      update
    rescue e
      BufferManager.flash "Can't read #{fn}: #{e.message}"
    end
  end

  def delete_attachment(*args)
    i = curpos - @attachment_lines_offset - (@selectors.empty? ? 0 : DECORATION_LINES) - @selectors.size
    #STDERR.puts "delete_attachment: i #{i}, curpos #{curpos}, alo #{@attachment_lines_offset}, selsize #{@selectors.size}"
    if i >= 0 && i < @attachments.size &&
       BufferManager.ask_yes_or_no("Delete attachment #{@attachments[i].basename}?")
      @attachments.delete_at i
      update
    end
  end

  # Run the editor on the email message file.  Return true if the use changed the file.
  def start_edit(command : String, filepath : String, is_gui : Bool, old_from : String)
    mtime = File.mtime filepath

    @editing = true
    BufferManager.completely_redraw_screen
    #STDERR.puts "about to run #{command}"
    success = BufferManager.shell_out command, is_gui
    #STDERR.puts "done running #{command}"
    @editing = false

    if File.exists?(filepath) && File.mtime(filepath) > mtime && success
      #STDERR.puts "start_edit: file #{filepath} was changed"
      @edited = true
    else
      #STDERR.puts "start_edit: file #{filepath} wasn't changed"
      BufferManager.completely_redraw_screen
      return @edited
    end

    #STDERR.puts "about to call parse_file"
    header, @body = parse_file filepath
    @header = purge_hash(header, NON_EDITABLE_HEADERS)
    # FIXME: implement this ugly function!
    #set_sig_edit_flag

    #STDERR.puts "checking from"
    if (a = @account_selector) && @header["From"] != old_from
      @account_user = @header["From"].as(String)
      a.set_to nil
    end

    #STDERR.puts "calling handle_new_text"
    handle_new_text @header, @body
    #rerun_crypto_selector_hook
    #STDERR.puts "calling update"
    update
    #STDERR.puts "calling completely_redraw_screen"
    BufferManager.completely_redraw_screen

    @edited
  end

  def send_message(*args) : Bool
    #STDERR.puts "Sending message #{@message_id}"
    #return false if warn_editing
    return false if !edited? && !BufferManager.ask_yes_or_no("Message unedited. Really send?")
    return false if Config.bool(:confirm_no_attachments) &&
                 mentions_attachments? && @attachments.size == 0 &&
		 !BufferManager.ask_yes_or_no("You haven't added any attachments. Really send?")#" stupid ruby-mode
    return false if Config.bool(:confirm_top_posting) &&
		 top_posting? &&
		 !BufferManager.ask_yes_or_no("You're top-posting. That makes you a bad person. Really send?") #" stupid ruby-mode

    if @header["From"] =~ /<?(\S+@(\S+?))>?$/
      acct = AccountManager.account_for($1)
    else
      acct = AccountManager.default_account
    end
    unless acct
      BufferManager.flash "No account for sending.  Unable to send!"
      return false
    end
    if acct.smtp_server == ""
      BufferManager.flash "Account does not define smtp_server.  Unable to send!"
      return false
    end

    # Set the EMail logger to point to our own csup log.
    if log_io = Redwood.log_io
      EMail::Client.log_io = log_io
    end

    # Build the email.
    date = Time.now
    begin
      m = build_message date
    rescue e
      warn "Problem building email: #{e.message}"
      BufferManager.flash "Problem building email: #{e.message}"
      return false
    end

    # Set up the SMTP client.
    config = EMail::Client::Config.new(acct.smtp_server, acct.smtp_port, helo_domain: "localhost")
    config.use_auth(acct.smtp_user, acct.smtp_password)
    config.use_tls(EMail::Client::TLSMode::SMTPS)
    config.use_tls(EMail::Client::TLSMode::STARTTLS)
    config.client_name = "Csup"
    client = EMail::Client.new(config)

    # Finally send the email.
    BufferManager.flash "Sending..."
    success = false
    begin
      client.start do
	success = send(m, override_message_id: false)
      end
    rescue e
      warn "Exception sending mail: #{e.message}"
      BufferManager.flash "Problem sending mail: #{e.message}"
      return false
    end
    unless success
      warn "Failure sending mail.  See log file for details."
      BufferManager.flash "Failure sending mail.  See log file for details."
      return false
    end

    SentManager.write_sent_message {|f| m.to_s(f) }
    BufferManager.kill_buffer buffer
    BufferManager.flash "Message sent!"
    return true
  end

  # If the email address is in format "name <addr>", return an EMail::Address object.
  # Otherwise return the email address unchanged, as a string.  If the address
  # is a blank space, return nil.
  def fix_email(s : String) : String | EMail::Address | Nil
    if s =~ /^\s*([^<]+)\s*<(.*)>$/
      name = $1.strip
      addr = $2.strip
      #STDERR.puts "EMail::Address.new #{addr}, #{name}"
      return EMail::Address.new(addr, name)
    elsif s =~ /^\s*$/
      return nil
    else
      return s
    end
  end

  def save_as_draft(*args)
    DraftManager.write_draft(@message_id) { |f| write_message f, false }
    BufferManager.kill_buffer buffer
    BufferManager.flash "Saved for later editing."
  end

  def build_message(date : Time) : EMail::Message
    email = EMail::Message.new
    @header.each do |k, v|
      #STDERR.puts "build_message: header #{k} = #{v}"
      case k
      when "From"
        from = v.as(String)
	# If From is in format "name <addr>", split out the two parts.
	if addr = fix_email(from)
	  email.from addr
	end
      when "To"
        to = v.as(Array(String))
	#STDERR.puts "setting To #{to}"
	to.each do |s|
	  if addr = fix_email(s)
	    email.to addr
	  end
	end
      when "Cc"
	cc = v.as(Array(String))
	#STDERR.puts "setting Cc #{cc}"
	cc.each do |s|
	  if addr = fix_email(s)
	    email.cc addr
	  end
	end
      when "Bcc"
	bcc = v.as(Array(String))
	#STDERR.puts "setting Bcc #{bcc}"
	bcc.each do |s|
	  if addr = fix_email(s)
	    email.bcc addr
	  end
	end
      when "Subject"
	email.subject(v.as(String))
      when "Date"
        # Ignore the date header, use current time instead.
      when "Message-ID", "Message-Id", "Message-id", "Mime-version"
        # Ignore these headers.  They cause build_message to fail.
      else
	if v.is_a?(String)
	  #STDERR.puts "Setting custom header string #{k}=#{v}"
	  email.custom_header(k, v)
	else
	  a = v.as(Array(String))
	  #STDERR.puts "Setting custom header array #{k}=#{a}"
	  email.custom_header(k, a.join(","))
	end
      end
    end

    # Set the date and message_id.  Note that setting the date doesn't actually work, because
    # EMail::Client.send overrides it when it calls mail_validate!.  However my fork
    # of the email shard adds an extra parameter to send to prevent overriding
    # message_id, which is very important for handling draft messages correctly.
    # See the call to send above.
    email.date(date)
    email.message_id(@message_id)

    # Add the body.
    body = @body.join("\n")
    unless @sig_edited
      body += "\n" + sig_lines.join("\n")
    end
    ## body must end in a newline or GPG signatures will be WRONG!
    body += "\n" unless body[-1] == '\n'
    email.message body

    # Add the attachments.
    @attachments.each {|a| a.attach_to_email(email)}

    return email
  end

  def write_message(f : IO, full=true, date=Time.now)
    email = build_message(date)
    email.to_s(f)
  end

end	# EditMessage Mode

end	# Redwood
