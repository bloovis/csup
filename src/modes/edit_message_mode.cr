require "./line_cursor_mode"
require "../horizontal_selector"

module Redwood

class EditMessageMode < LineCursorMode
  mode_class send_message, edit_message_or_field, edit_to, edit_cc,
	     edit_subject, default_edit_message, alternate_edit_message,
	     save_as_draft, attach_file, delete_attachment,
	     move_cursor_right, move_cursor_left

  DECORATION_LINES = 1

  FORCE_HEADERS = %w(From To Cc Bcc Subject)
  MULTI_HEADERS = %w(To Cc Bcc)
  NON_EDITABLE_HEADERS = %w(Message-Id Date)

  alias HeaderHash = Hash(String, String)

  property body = Array(String).new
  property header = HeaderHash.new
  bool_getter edited
  property text = TextLines.new

  register_keymap do |k|
    k.add :send_message, "Send message", 'y'
    k.add :edit_message_or_field, "Edit selected field", 'e'
    k.add :edit_to, "Edit To:", 't'
    k.add :edit_cc, "Edit Cc:", 'c'
    k.add :edit_subject, "Edit Subject", 's'
    k.add :default_edit_message, "Edit message (default)", :enter
    k.add :alternate_edit_message, "Edit message (alternate, asynchronously)", 'E'
    k.add :save_as_draft, "Save as draft", 'P'
    k.add :attach_file, "Attach a file", 'a'
    k.add :delete_attachment, "Delete an attachment", 'd'
    k.add :move_cursor_right, "Move selector to the right", :right, 'l'
    k.add :move_cursor_left, "Move selector to the left", :left, 'h'
  end

  def initialize(opts = Opts.new)
    @header = opts.delete_str(:header) || HeaderHash.new
    @header_lines = Array(String).new

    @body = opts.delete_str(:body) || Array(String).new

    if opts.member(:attachments)
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

    @account_selector = nil
    # only show account selector if there is more than one email address
    if Config.bool(:account_selector) && AccountManager.user_emails.size > 1
      # In Sup, a nil value was used for Customized.  In Csup we use
      # blank string to avoid lots of compile-time nil errors.
      @account_selector =
        HorizontalSelector.new "Account:", # label
			       AccountManager.user_emails + [""], # vals
			       AccountManager.user_emails + ["Customized"] #labels

      if @header["From"] =~ /<?(\S+@(\S+?))>?$/
        # TODO: this is ugly. might implement an AccountSelector and handle
        # special cases more transparently.
        account_from = @account_selector.can_set_to?($1) ? $1 : nil
        @account_selector.set_to account_from
      else
        @account_selector.set_to ""
      end

      # A single source of truth might better than duplicating this in both
      # @account_user and @account_selector.
      @account_user = @header["From"]

      add_selector @account_selector
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

  def regen_text
    @text = TextLines.new
    header, @header_lines = format_headers(purge_hash(@header, NON_EDITABLE_HEADERS)) # + [""] <-- what is this?
    #@text = header + [""] + @body
    header.each {|l| @text << l}
    @text << ""
    @body.each {|l| @text << l}
    #@text += sig_lines unless @sig_edited
    #if !@sig_edited
    #  sig_lines.each {|l} @text << l}
    #end

    @attachment_lines_offset = 0

    unless @attachments.empty?
      @text << ""
      @attachment_lines_offset = @text.size
      #@text += (0 ... @attachments.size).map { |i| [[:attachment_color, "+ Attachment: #{@attachment_names[i]} (#{@attachments[i].body.size.to_human_size})"]] }
      @attachments.each do |a|
        @text << {:attachment_color, "+ Attachment: #{a} (#{File.size(a).to_human_size})"}
      end
    end
  end

  def format_headers(header : HeaderHash) : Tuple(TextLines, Array(String))
    header_lines = Array(String).new	# array of header keys
    headers = TextLines.new
    (FORCE_HEADERS + (header.keys - FORCE_HEADERS)).each do |h|
      lines = make_lines "#{h}:", header[h]
      lines.each do |l|
        header_lines << h
	headers << l
      end
    end
    return {headers, header_lines}
  end

end	# EditMessage Mode

end	# Redwood
