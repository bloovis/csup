require "./line_cursor_mode"
require "../horizontal_selector"
require "../shellwords"
require "../rfc2047"
require "../opts"

module Redwood

class EditMessageMode < LineCursorMode
  mode_class send_message, default_edit_message #,
	     #edit_message_or_field, edit_to, edit_cc,
	     #edit_subject,  alternate_edit_message,
	     #save_as_draft, attach_file, delete_attachment,
	     #move_cursor_right, move_cursor_left

  DECORATION_LINES = 1

  FORCE_HEADERS = %w(From To Cc Bcc Subject)
  MULTI_HEADERS = %w(To Cc Bcc)
  NON_EDITABLE_HEADERS = %w(Message-Id Date)

  property body = Array(String).new
  property header = HeaderHash.new
  property text = TextLines.new
  property account_user = ""

  property account_selector : HorizontalSelector
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
    #k.add :save_as_draft, "Save as draft", 'P'
    #k.add :attach_file, "Attach a file", 'a'
    #k.add :delete_attachment, "Delete an attachment", 'd'
    #k.add :move_cursor_right, "Move selector to the right", "Right", 'l'
    #k.add :move_cursor_left, "Move selector to the left", "Left", 'h'
  end

  def initialize(opts = Opts.new)
    @header = opts.delete_hash(:header) || HeaderHash.new
    @header_lines = Array(String).new

    @body = opts.delete_strarray(:body) || Array(String).new

    if opts.member?(:attachments)
      # In Sup, attachments was a hash of filename => RMail attachment.
      # In Csup, attachments is just an array of filenames.
      @attachments = opts.strarray(:attachments)
    else
      @attachments = Array(String).new
    end

    hostname = `hostname`

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

      # FIXME: when we have more than one selector, enable this line.
      #add_selector selector
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
  def purge_hash(h, a)
    newh = h.clone
    a.each {|key| newh.delete(key) }
    return newh
  end

  def update
    if a = @account_selector
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
      STDERR.puts "regen_text: adding line '#{l}'"
      @text << l
    end
    @text << ""
    @body.each {|l| @text << l}
    #@text += sig_lines unless @sig_edited
    if !@sig_edited
      sig_lines.each {|l| @text << l}
    end

    @attachment_lines_offset = 0

    if (attachments = @attachments) && (attachments.size > 0)
      @text << ""
      @attachment_lines_offset = @text.size
      #@text += (0 ... attachments.size).map { |i| [[:attachment_color, "+ Attachment: #{@attachment_names[i]} (#{@attachments[i].body.size.to_human_size})"]] }
      attachments.each do |a|
        @text << [{:attachment_color, "+ Attachment: #{a} (#{File.size(a).to_human_size})"}]
      end
    end
  end

  def parse_raw_email_header(f : File) : Hash(String, String)
    header = Hash(String, String).new
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
      lines = make_lines "#{h}:", header[h]
      lines.each do |l|
        STDERR.puts "format_headers: adding line #{l} to headers"
        header_lines << h
	headers << l
      end
    end
    return {headers, header_lines}
  end

  def make_lines(header : String, things : String | Array(String)) : Array(String)
    if things.is_a?(String)
      STDERR.puts "make_lines: string for #{header} = #{things}"
      return [header + " " + things]
    else
      if things.size == 0
        return [header]
      else
	lines = Array(String).new
        things.each_with_index do |name, i|
          #raise "an array: #{name.inspect} (things #{things.inspect})" if Array === name
          STDERR.puts "make_lines: header #{header}, name[#{i}] = #{name}"
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

  def default_edit_message(*args)
    # FIXME: will we every support async edit?  Maybe not.
    #if $config[:always_edit_async]
    #  return edit_message_async
    #else
      return edit_message
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
      return
    end

    # prepare command line arguments
    editor = Config.str(:editor) || ENV["EDITOR"] || "/usr/bin/vi"

    return unless file = @file
    filepath = file.path
    pos = [@curpos - selector_lines, @header_lines.size].max + 1
    ENV["LINE"] = pos.to_s
    ENV["FILE"] = filepath
    command = editor.gsub(/\$LINE\b/, pos.to_s)
    command = command + " $FILE" unless command.includes?("$FILE")
    command = command.gsub(/\$FILE\b/, Shellwords.escape(filepath))
    start_edit command, filepath, false, old_from	# false was is_gui
  end

  def save_message_to_file
    #raise 'cannot save message to another file while editing' if @editing
    sig = sig_lines.join("\n")
    file = File.tempfile("csup.#{self.class.name.gsub(/.*::/, "").camel_to_hyphy}.eml")
    @file = file
    #STDERR.puts "About to call format_headers with header #{@header}"
    headers = format_headers(purge_hash(@header, NON_EDITABLE_HEADERS))[0]
    #STDERR.puts "format_headers returned headers #{headers}"
    headers.each {|l| file.puts l}
    file.puts
    file.puts

    text = @body.join("\n")
    file.puts text
    file.puts sig if (Config.bool(:edit_signature) && !@sig_edited)
    file.close
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

  def start_edit(command : String, filepath : String, is_gui : Bool, old_from : String)
    mtime = File.mtime filepath

    @editing = true
    BufferManager.completely_redraw_screen
    success = BufferManager.shell_out command, is_gui
    @editing = false

    if File.exists?(filepath) && File.mtime(filepath) > mtime && success
      @edited = true
    else
      STDERR.puts "start_edit: file #{filepath} wasn't changed"
      File.delete?(filepath)
      BufferManager.completely_redraw_screen
      return @edited
    end

    header, @body = parse_file filepath
    @header = purge_hash(header, NON_EDITABLE_HEADERS)
    # FIXME: implement this ugly function!
    #set_sig_edit_flag

    if @account_selector && @header["From"] != old_from
      @account_user = @header["From"].as(String)
      @account_selector.set_to nil
    end

    handle_new_text @header, @body
    #rerun_crypto_selector_hook
    update
    BufferManager.completely_redraw_screen

    @edited
  end

  def send_message(*args)
    BufferManager.flash("send not implemented!")
  end
end	# EditMessage Mode

end	# Redwood
