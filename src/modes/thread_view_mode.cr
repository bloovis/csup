require "./line_cursor_mode"
require "./text_mode"
require "./compose_mode"
require "./reply_mode"
require "./resume_mode"
require "./forward_mode"
require "./can_alias_contacts"

module Redwood

class ThreadViewMode < LineCursorMode
  mode_class expand_all_quotes, expand_all_messages, select_item,
	     align_current_message, toggle_detailed_header, show_header, show_message,
	     pipe_message, jump_to_next_and_open, jump_to_prev_and_open,
	     jump_to_next_open, jump_to_prev_open,
	     compose, search, reply_cmd, reply_all, edit_draft, send_draft,
	     edit_labels, forward, save_to_disk, save_all_to_disk, edit_alias,
	     toggle_starred, toggle_new, toggle_wrap, goto_uri,
	     archive_and_kill, delete_and_kill, spam_and_kill, unread_and_kill, do_nothing_and_kill,
	     archive_and_next, delete_and_next, spam_and_next, unread_and_next, do_nothing_and_next,
	     archive_and_prev, delete_and_prev, spam_and_prev, unread_and_prev, do_nothing_and_prev

  class Layout
    property state = :none
  end
  alias ChunkLayout = Layout

  ## this holds all info we need to lay out a message
  class MessageLayout < Layout
    property top : Int32 = 0
    property bot : Int32 = 0
    property prev : Message? = nil
    property next : Message? = nil
    property depth : Int32 = 0
    property width : Int32 = 0
    property color : Symbol = :text_color
    property star_color : Symbol = :text_color
    property orig_new : Bool = false
    property toggled_state : Bool = false
  end

  register_keymap do |k|
    k.add :toggle_detailed_header, "Toggle detailed header", 'h'
    k.add :show_header, "Show full message header", 'H'
    k.add :show_message, "Show full message (raw form)", 'V'
    k.add :select_item, "Expand/collapse or activate item", "C-m"
    k.add :expand_all_messages, "Expand/collapse all messages", 'E'
    k.add :edit_draft, "Edit draft", 'e'
    k.add :send_draft, "Send draft", 'y'
    k.add :edit_labels, "Edit or add labels for a thread", 'l'
    k.add :expand_all_quotes, "Expand/collapse all quotes in a message", 'o'
    k.add :jump_to_next_open, "Jump to next open message", 'n'
    k.add :jump_to_next_and_open, "Jump to next message and open", "C-n"
    k.add :jump_to_prev_open, "Jump to previous open message", 'p'
    k.add :jump_to_prev_and_open, "Jump to previous message and open", "C-p"
    k.add :align_current_message, "Align current message in buffer", 'z'
    k.add :toggle_starred, "Star or unstar message", '*'
    k.add :toggle_new, "Toggle unread/read status of message", 'N'
    k.add :reply_cmd, "Reply to a message", 'r'
    k.add :reply_all, "Reply to all participants of this message", 'G'
    k.add :forward, "Forward a message or attachment", 'f'
    k.add :edit_alias, "Edit alias/nickname for a person", 'i'
    k.add :save_to_disk, "Save message/attachment to disk", 's'
    k.add :save_all_to_disk, "Save all attachments to disk", 'A'
    k.add :search, "Search for messages from particular people", 'S'
    k.add :compose, "Compose message to person", 'm'
    k.add :pipe_message, "Pipe message or attachment to a shell command", '|'

    k.add :archive_and_next, "Archive this thread, kill buffer, and view next", 'a'
    k.add :delete_and_next, "Delete this thread, kill buffer, and view next", 'd'
    k.add :toggle_wrap, "Toggle wrapping of text", 'w'
    k.add :goto_uri, "Goto uri under cursor", 'g'

    k.add_multi "(a)rchive/(d)elete/mark as (s)pam/mark as u(N)read:", '.' do |kk|
      kk.add :archive_and_kill, "Archive this thread and kill buffer", 'a'
      kk.add :delete_and_kill, "Delete this thread and kill buffer", 'd'
      kk.add :spam_and_kill, "Mark this thread as spam and kill buffer", 's'
      kk.add :unread_and_kill, "Mark this thread as unread and kill buffer", 'N'
      kk.add :do_nothing_and_kill, "Just kill this buffer", '.'
    end
    k.add_multi "(a)rchive/(d)elete/mark as (s)pam/mark as u(N)read/do (n)othing:", ',' do |kk|
      kk.add :archive_and_next, "Archive this thread and view next", 'a'
      kk.add :delete_and_next, "Delete this thread, kill buffer, and view next", 'd'
      kk.add :spam_and_next, "Mark this thread as spam, kill buffer, and view next", 's'
      kk.add :unread_and_next, "Mark this thread as unread, kill buffer, and view next", 'N'
      kk.add :do_nothing_and_next, "Kill buffer, and view next", 'n', ','
    end
    k.add_multi "(a)rchive/(d)elete/mark as (s)pam/mark as u(N)read/do (n)othing:", ']' do |kk|
      kk.add :archive_and_prev, "Archive this thread, kill buffer, and view previous", 'a'
      kk.add :delete_and_prev, "Delete this thread, kill buffer, and view previous", 'd'
      kk.add :spam_and_prev, "Mark this thread as spam, kill buffer, and view previous", 's'
      kk.add :unread_and_prev, "Mark this thread as unread, kill buffer, and view previous", 'N'
      kk.add :do_nothing_and_prev, "Kill buffer, and view previous", 'n', ']'
    end
  end

  # Instance variables
  @text = TextLines.new
  @indent_spaces = 0
  @chunk_lines = SparseArray(Chunk | Message).new
  @message_lines = SparseArray(Message).new
  @person_lines = SparseArray(Person).new
  @global_message_state = :none
  @dying = false

  def lines
    @text.size
  end

  def [](n) : Text
    @text[n]
  end

  def initialize(thread : MsgThread, @index_mode : ThreadIndexMode)
    super()
    @indent_spaces = Config.int(:indent_spaces)
    @thread = thread

    @layout = SavingHash(Message, MessageLayout).new { MessageLayout.new }
    @chunk_layout = SavingHash(Chunk, ChunkLayout).new { ChunkLayout.new }
    earliest, latest = nil, nil
    latest_date = nil
    altcolor = false

    @thread.each do |m, d, p|
      next unless m
      earliest ||= m
      @layout[m].state = initial_state_for m
      @layout[m].toggled_state = false
      @layout[m].color = altcolor ? :alternate_patina_color : :message_patina_color
      @layout[m].star_color = altcolor ? :alternate_starred_patina_color : :starred_patina_color
      @layout[m].orig_new = m.has_label? :read
      altcolor = !altcolor
      if latest_date.nil? || m.date > latest_date
        latest_date = m.date
        latest = m
      end
    end

    @wrap = true

    @layout[latest].state = :open if @layout[latest].state == :closed
    @layout[earliest].state = :detailed if (earliest && earliest.has_label?(:unread)) || @thread.size == 1

#    display_thread(thread) # old test code
  end

  def toggle_wrap(*args)
    @wrap = !@wrap
    regen_text
    buffer.mark_dirty if buffer
  end

  def initial_state_for(m : Message) : Symbol
    if m.has_label?(:starred) || m.has_label?(:unread)
      :open
    else
      :closed
    end
  end

  ## a little hacky---since regen_text can depend on buffer features like the
  ## content_width, we don't call it in the constructor, and instead call it
  ## here, which is set before we're responsible for drawing ourself.
  def buffer=(b : Buffer)
    super
    regen_text
  end

  def show_header(*args)
    return unless m = @message_lines[curpos]
    BufferManager.spawn_unless_exists("Full header for #{m.id}") do
      TextMode.new m.raw_header
    end
  end

  def show_message(*args)
    return unless m = @message_lines[curpos]
    BufferManager.spawn_unless_exists("Raw message for #{m.id}") do
      TextMode.new m.raw_message
    end
  end

  def reply_all(*args)
    reply("all")
  end

  def reply_cmd(*args)
    reply("none")
  end

  def reply(type_arg : String)
    return unless m = @message_lines[curpos]
    mode = ReplyMode.new(m, type_arg)
    BufferManager.spawn "Reply to #{m.subj}", mode
  end

  def forward(*args)
    if(chunk = @chunk_lines[curpos]) && chunk.is_a?(AttachmentChunk)
      att = "part|#{chunk.part.filename}|#{chunk.message.id}|#{chunk.part.id}|" +
            "#{chunk.part.content_type}|#{chunk.part.content_size}"
      ForwardMode.spawn_nicely(Opts.new({:attachments => [att]}))
    elsif(m = @message_lines[curpos])
      ForwardMode.spawn_nicely(Opts.new({:message => m}))
    end
  end

  def toggle_detailed_header(*args)
    return unless m = @message_lines[curpos]
    @layout[m].state = (@layout[m].state == :detailed ? :open : :detailed)
    update
  end

  include CanAliasContacts
  def edit_alias(*args)
    return unless p = @person_lines[curpos]
    alias_contact p
    update
  end

  def search(*args)
    return unless p = @person_lines[curpos]
    mode = PersonSearchResultsMode.new [p]
    BufferManager.spawn "Search for #{p.name}", mode
    #mode.load_threads :num => mode.buffer.content_height
  end

  def compose(*args)
    p = @person_lines[curpos]
    if p
      ComposeMode.spawn_nicely(Opts.new({:to_default => p.full_address}))
    else
      ComposeMode.spawn_nicely
    end
  end

  def edit_labels(*args)
    thread = @thread	# save value for undo
    old_labels = thread.labels
    reserved_labels = old_labels & LabelManager::RESERVED_LABELS
    new_labels = BufferManager.ask_for_labels(:label, "Labels for thread: ",
					      thread.labels)
    return unless new_labels
    thread.labels = reserved_labels + new_labels
    new_labels.each { |l| LabelManager << l }
    update
    UpdateManager.relay self, :labeled, thread
    Notmuch.save_thread thread
    UndoManager.register "labeling thread" do
      thread.labels = old_labels
      Notmuch.save_thread thread
      UpdateManager.relay self, :labeled, thread
    end
  end

  def toggle_starred(*args)
    return unless m = @message_lines[curpos]
    toggle_label m, :starred
  end

  def toggle_new(*args)
    return unless m = @message_lines[curpos]
    toggle_label m, :unread
  end

  def toggle_label(m : Message, label : Symbol | String)
    if m.has_label? label
      m.remove_label label
    else
      m.add_label label
    end
    ## TODO: don't recalculate EVERYTHING just to add a stupid little
    ## star to the display
    update
    Notmuch.save_thread @thread
    #STDERR.puts "toggle_label: relay :single_message_labeled, starred = #{@thread.has_label? :starred}"
    UpdateManager.relay self, :single_message_labeled, @thread
  end

  def update
    regen_text
    #@text.each_with_index do |l, i|
      #STDERR.puts "update: line #{i} = #{l}"
    #end
    buffer.mark_dirty if buffer
    #STDERR.puts "update: buffer dirty = #{buffer.dirty}"
  end

  ## here we generate the actual content lines. we accumulate
  ## everything into @text, and we set @chunk_lines and
  ## @message_lines, and we update @layout.
  def regen_text
    @text = [] of Text
    @chunk_lines = SparseArray(Chunk | Message).new
    @message_lines = SparseArray(Message).new
    @person_lines = SparseArray(Person).new

    prevm = nil
    return unless thread = @thread
    thread.each do |m, depth, parent|
      #unless m.is_a? Message # handle nil and :fake_root
      #  @text += chunk_to_lines m, nil, @text.length, depth, parent
      #  next
      #end
      l = @layout[m]
      #STDERR.puts "regen_text: processing message #{m.id}, layout state #{l.state}"

      ## is this still necessary?
      next unless @layout[m].state # skip discarded drafts

      ## build the patina
      #STDERR.puts "regen_text: calling chunk_to_lines for message #{m.id}"
      text = chunk_to_lines m, l.state, @text.length, depth, parent, l.color, l.star_color

      l.top = @text.length
      l.bot = @text.length + text.length # updated below
      l.prev = prevm
      l.next = nil
      l.depth = depth
      # l.state we preserve
      l.width = 0 # updated below
      @layout[l.prev].next = m if l.prev

      (0 ... text.length).each do |i|
        @chunk_lines[@text.length + i] = m
        @message_lines[@text.length + i] = m
	#This value of lw doesn't seem to be used.
        #lw = text[i].flatten.select { |x| x.is_a? String }.map { |x| x.display_length }.sum
      end

      @text += text
      prevm = m
      if l.state != :closed
        m.chunks.each do |c|
	  #STDERR.puts "regen_text: msg #{m.id}, chunk #{c.type} has #{c.lines.size} lines"
          cl = @chunk_layout[c]

          ## set the default state for chunks
          if cl.state == :none
	    if c.expandable? # && c.respond_to?(:initial_state)
	      cl.state = c.initial_state
	    else
	      cl.state = :closed
	    end
	  end

	  #STDERR.puts "About to call chunk_to_lines for chunk #{c.type}, state #{cl.state}"
          text = chunk_to_lines c, cl.state, @text.length, depth
	  #STDERR.puts "chunk_to_lines returned #{text.size} lines"
	  #text.each {|t| STDERR.puts "line: #{t}"}
          (0 ... text.length).each do |i|
            @chunk_lines[@text.length + i] = c
            @message_lines[@text.length + i] = m
	    #lw = text[i].flatten.select { |x| x.is_a? String }.map { |x| x.display_length }.sum - (depth * @indent_spaces)
	    lw = 0
	    line = text[i]
	    if line.is_a?(String)
	      lw += line.display_length
	    else
	      line.each {|widget| lw += widget[1].display_length}
	    end
            l.width = lw if lw > l.width
          end
          @text += text
        end
        @layout[m].bot = @text.length
      end
    end
  end

  def message_patina_lines(m : Message, state : Symbol, start : Int32,
			   parent : Message?, prefix : String, color : Symbol,
			   star_color : Symbol) : TextLines
    #STDERR.puts "message_patina_lines processing message #{m.id}, state #{state}"
    prefix_widget = {color, prefix}
    open_widget = {color, (state == :closed ? "+ " : "- ")}
    new_widget = {color, (m.has_label?(:unread) ? "N" : " ")}
    starred_widget = if m.has_label?(:starred)
        {star_color, "*"}
      else
        {color, " "}
      end
    attach_widget = {color, (m.has_label?(:attachment) ? "@" : " ")}

    case state
    when :open, :closed
      @person_lines[start] = m.from
      segments = [
        m.from ? m.from.mediumname : '?',
        # 'to',
        # m.recipients.map { |l| l.shortname.fix_encoding! }.join(', '),
        m.subj,
        m.date.to_nice_s,
        "(#{m.date.to_nice_distance_s})",
      ]
      title_widget = {color, segments.join("  ")}
      header_widgets = WidgetArray.new
      [prefix_widget, open_widget, new_widget, attach_widget, starred_widget, title_widget].each do |w|
        header_widgets << w
      end
      lines = TextLines.new
      lines << header_widgets
      return lines
    when :detailed
      #STDERR.puts "processing detailed view for #{m.id}"
      @person_lines[start] = m.from
      from_line = WidgetArray.new
      [prefix_widget,
       open_widget,
       new_widget,
       attach_widget,
       starred_widget,
       {color, "From: #{m.from ? format_person(m.from) : '?'}"}
      ].each {|widget| from_line << widget}

      addressee_lines = [] of String
      unless m.to.empty?
        m.to.each_with_index { |p, i| @person_lines[start + addressee_lines.length + i + 1] = p }
        addressee_lines += format_person_list "   To: ", m.to
      end
      unless m.cc.empty?
        m.cc.each_with_index { |p, i| @person_lines[start + addressee_lines.length + i + 1] = p }
        addressee_lines += format_person_list "   Cc: ", m.cc
      end
      unless m.bcc.empty?
        m.bcc.each_with_index { |p, i| @person_lines[start + addressee_lines.length + i + 1] = p }
        addressee_lines += format_person_list "   Bcc: ", m.bcc
      end

      headers = {
        "Date" => "#{m.date.to_message_nice_s} (#{m.date.to_nice_distance_s})",
        "Subject" => m.subj
      }

      show_labels = @thread.labels - LabelManager::HIDDEN_RESERVED_LABELS
      unless show_labels.empty?
        headers["Labels"] = show_labels.map { |x| x.to_s }.sort.join(", ")
      end
      if parent
        headers["In reply to"] = "#{parent.from.mediumname}'s message of #{parent.date.to_message_nice_s}"
      end

      # HookManager.run "detailed-headers", :message => m, :headers => headers

      lines = TextLines.new
      lines << from_line
      header_lines = headers.map {|k,v| "   #{k}: #{v}"}
      (addressee_lines + header_lines).each do |l|
        lines << [{color, prefix + "  " + l}]
      end
      return lines
      #lines.each {|l| STDERR.puts "detail line: #{l}"}
      return lines
      #return from_line + (addressee_lines +
      #       headers.map { |k, v| "   #{k}: #{v}" }).
      #	     map {|l| [{color, prefix + "  " + l}] }
    end
    return TextLines.new	# if all else fails, return empty array
  end

  def format_person_list(prefix : String, people : Array(Person)) : Array(String)
    ptext = people.map { |p| format_person p }
    pad = " " * prefix.display_length
    [prefix + ptext.first + (ptext.length > 1 ? "," : "")] +
      ptext[1 .. -1].map_with_index do |e, i|
        pad + e + (i == ptext.length - 1 ? "" : ",")
      end
  end

  def format_person(p : Person) : String
    p.longname + (ContactManager.is_aliased_contact?(p) ? " (#{ContactManager.alias_for p})" : "")
  end

  def maybe_wrap_text(lines : Array(String)) : Array(String)
    if @wrap
      config_width = Config.int(:wrap_width)
      if config_width && config_width != 0
        width = [config_width, buffer.content_width].min
      else
        width = buffer.content_width
      end
      lines = lines.map { |l| l.chomp.wrap width }.flatten
    end
    return lines
  end

  ## todo: check arguments on this overly complex function
  def chunk_to_lines(chunk : Chunk | Message,
		     state : Symbol,
		     start : Int32,
		     depth : Int32,
		     parent : Message? = nil,
		     color : Symbol? = nil,	# blotz - color and star_color should not be nil
		     star_color : Symbol? = nil) : TextLines
    ret = TextLines.new
    prefix = " " * @indent_spaces * depth
    if chunk.is_a?(Message)
      #STDERR.puts "chunk_to_lines: processing message #{chunk.id}"
      ret = message_patina_lines(chunk, state, start, parent, prefix, color, star_color)
      if chunk.is_draft?
	ret << [{:draft_notification_color,
                 prefix + " >>> This message is a draft. Hit 'e' to edit, 'y' to send. <<<"}]
      end
    else
      #STDERR.puts "chunk_to_lines: processing chunk #{chunk.type}, state #{state}"
      #raise "Bad chunk: #{chunk.inspect}" unless chunk.respond_to?(:inlineable?) ## debugging
      if chunk.inlineable?
        lines = maybe_wrap_text(chunk.lines)
	lines.each {|line| ret << [{chunk.color, "#{prefix}#{line}"}]}
      elsif chunk.expandable?
        case state
        when :closed
          ret << [{chunk.patina_color, "#{prefix}+ #{chunk.patina_text}"}]
        when :open
          lines = maybe_wrap_text(chunk.lines)
	  ret << [{chunk.patina_color, "#{prefix}- #{chunk.patina_text}"}]
	  lines.each { |line| ret << [{chunk.color, "#{prefix}#{line}"}] }
        end
      else
        ret << [{chunk.patina_color, "#{prefix}x #{chunk.patina_text}"}]
      end
    end
    return ret
  end

  # Commands

  ## called when someone presses enter when the cursor is highlighting
  ## a chunk. for expandable chunks (including messages) we toggle
  ## open/closed state; for viewable chunks (like attachments) we
  ## view.
  def select_item(*args)
    return unless chunk = @chunk_lines[curpos]
    if chunk.is_a?(Chunk) && chunk.type == :text
      ## if the cursor is over a text region, expand/collapse the
      ## entire message
      chunk = @message_lines[curpos]
    end
    layout = if chunk.is_a?(Message)
      @layout[chunk]
    elsif chunk && chunk.expandable?
      @chunk_layout[chunk]
    end
    if layout
      layout.state = (layout.state != :closed ? :closed : :open)
      #cursor_down if layout.state == :closed # too annoying
      update
    elsif chunk.is_a?(Chunk) && chunk.viewable?
      view chunk
    end
    if chunk.is_a?(Message) && Config.bool(:jump_to_open_message)
      jump_to_message chunk
      jump_to_next_open if layout && layout.state == :closed
    end
  end

  def save_to_disk(*args)
    return unless chunk = @chunk_lines[curpos]
    case chunk
    when AttachmentChunk
      default_dir = Config.str(:default_attachment_save_dir) || ""
      default_dir = ENV["HOME"] if default_dir.empty?
      default_fn = Path.new(default_dir, chunk.safe_filename).expand.to_s
      fn = BufferManager.ask_for_filename :filename, "Save attachment to file or directory: ",
				           default_fn, true
      return unless fn

      # if user selects directory use file name from message
      if File.directory? fn
        fn = File.join(fn, chunk.filename)
      end
      chunk.save(fn)
    else
      return unless m = @message_lines[curpos]
      fn = BufferManager.ask_for_filename :filename, "Save message to file: "
      return unless fn
      Notmuch.save_part(m.id, 0, fn)
    end
  end

  def save_all_to_disk(*args)
    return unless m = @message_lines[curpos]
    default_dir = Config.str(:default_attachment_save_dir) || "."
    folder = BufferManager.ask_for_filename :filename, "Save all attachments to folder: ", default_dir, true
    return unless folder
    unless File.directory?(folder)
      BufferManager.flash("#{folder} is not a directory!")
      return
    end

    num = 0
    num_errors = 0
    m.chunks.each do |chunk|
      next unless chunk.is_a?(AttachmentChunk)
      fn = File.join(folder, chunk.safe_filename)
      unless chunk.save(fn)
        num_errors += 1
      end
      num += 1
    end

    if num == 0
      BufferManager.flash "Didn't find any attachments!"
    else
      if num_errors == 0
        BufferManager.flash "Wrote #{num.pluralize "attachment"} to #{folder}."
      else
        BufferManager.flash "Wrote #{(num - num_errors).pluralize "attachment"} to #{folder}; couldn't write #{num_errors} of them (see log)."
      end
    end
  end

  def edit_draft(*args)
    return unless m = @message_lines[curpos]
    #STDERR.puts "edit_draft: id #{m.id}, filename #{m.filename}, is_draft #{m.is_draft?}"
    raise "edit_draft: file #{m.filename} does not exist" unless File.exists?(m.filename)
    if m.is_draft?
      #STDERR.puts "edit_draft: creating ResumeMode"
      mode = ResumeMode.new m
      BufferManager.spawn "Edit message", mode
      BufferManager.kill_buffer self.buffer
      mode.default_edit_message
    else
      BufferManager.flash "Not a draft message!"
    end
  end

  def send_draft(*args)
    return unless m = @message_lines[curpos]
    if m.is_draft?
      mode = ResumeMode.new m
      BufferManager.spawn "Send message", mode
      BufferManager.kill_buffer self.buffer
      mode.send_message
    else
      BufferManager.flash "Not a draft message!"
    end
  end

  def jump_to_first_open
    m = @message_lines[0]
    #STDERR.puts "jump_to_first_open, m = #{m}"
    return unless m
    if @layout[m].state != :closed
      jump_to_message m #, true
    else
      jump_to_next_open #true
    end
  end

  def jump_to_next_and_open(*args)
    # return continue_search_in_buffer if in_search? # err.. don't know why im doing this

    m = (curpos ... @message_lines.length).argfind { |i| @message_lines[i] }
    return unless m

    nextm = @layout[m].next
    return unless nextm

    if @layout[m].toggled_state == true
      @layout[m].state = :closed
      @layout[m].toggled_state = false
      update
    end

    if @layout[nextm].state == :closed
      @layout[nextm].state = :open
      @layout[nextm].toggled_state = true
    end

    jump_to_message nextm if nextm
    update if @layout[nextm].toggled_state
  end

  def jump_to_next_open(force_alignment=false, *args)
    return continue_search_in_buffer if in_search? # hack: allow 'n' to apply to both operations
    m = (curpos ... @message_lines.length).argfind { |i| @message_lines[i] }
    return unless m
    while nextm = @layout[m].next
      break if @layout[nextm].state != :closed
      m = nextm
    end
    jump_to_message nextm, force_alignment if nextm
  end

  def jump_to_prev_and_open(*args)
    m = (0 .. curpos).to_a.reverse.argfind { |i| @message_lines[i] }
    return unless m

    nextm = @layout[m].prev
    return unless nextm

    if @layout[m].toggled_state == true
      @layout[m].state = :closed
      @layout[m].toggled_state = false
      update
    end

    if @layout[nextm].state == :closed
      @layout[nextm].state = :open
      @layout[nextm].toggled_state = true
    end

    jump_to_message nextm if nextm
    update if @layout[nextm].toggled_state
  end

  def align_current_message(*args)
    return unless m = @message_lines[curpos]
    jump_to_message m, true
  end

  def jump_to_prev_open(*args)
    m = (0 .. curpos).to_a.reverse.argfind { |i| @message_lines[i] } # bah, .to_a
    return unless m
    ## jump to the top of the current message if we're in the body;
    ## otherwise, to the previous message

    top = @layout[m].top
    if curpos == top
      while(prevm = @layout[m].prev)
        break if @layout[prevm].state != :closed
        m = prevm
      end
      jump_to_message prevm if prevm
    else
      jump_to_message m
    end
  end

  def jump_to_message(m, force_alignment=false)
    l = @layout[m]
    #STDERR.puts "jump_to_message: l.top = #{l.top}"

    ## boundaries of the message
    message_left = l.depth * @indent_spaces
    message_right = message_left + l.width

    ## calculate leftmost column
    left = if force_alignment # force mode: align exactly
      message_left
    else # regular: minimize cursor movement
      ## leftmost and rightmost are boundaries of all valid left-column
      ## alignments.
      leftmost = [message_left, message_right - buffer.content_width + 1].min
      rightmost = message_left
      leftcol.clamp(leftmost, rightmost)
    end

    jump_to_line l.top    # move vertically
    jump_to_col left      # move horizontally
    set_cursor_pos l.top  # set cursor pos
  end

  def expand_all_messages(*args)
    #STDERR.puts "ThreadViewMode: expand_all_messages"
    if @global_message_state == :none
      @global_message_state = :closed
    end
    @global_message_state = (@global_message_state == :closed ? :open : :closed)
    #STDERR.puts "expand_all_messages: setting global message state to #{@global_message_state}"
    @layout.each do |m, l|
      #STDERR.puts "expand_all_messages: setting layout for #{m.id} to #{@global_message_state}"
      l.state = @global_message_state
    end
    update
  end

  def expand_all_quotes(*args)
    if(m = @message_lines[curpos])
      quotes = m.chunks.select { |c| (c.type == :quote || c.type == :sig) && c.lines.length > 1 }
      numopen = quotes.reduce(0) { |s, c| s + (@chunk_layout[c].state == :open ? 1 : 0) }
      newstate = numopen > quotes.length / 2 ? :closed : :open
      quotes.each { |c| @chunk_layout[c].state = newstate }
      update
    end
  end

  def status
    #STDERR.puts "ThreadViewMode.status, caller #{caller[1]}"
    set_status	# let LineCursorMode set its status first
    user_labels = @thread.labels.to_a.map do |l|
      l.to_s if LabelManager.user_defined_labels.member?(l)
    end.compact.join(",")
    user_labels = (user_labels.empty? && "" || "<#{user_labels}>")
    #STDERR.puts "ThreadViewMode.status: user labels #{user_labels}"
    [user_labels, super].join(" -- ")
  end

  # This differs from the goto_uri in Sup in that it only looks at one line.
  # That's because it almost never worked when it tried to collect several
  # lines together.  You should first use the 'w' command to un-wrap the text;
  # that way the URL will appear on one line.
  def goto_uri(*args)
    unless (chunk = @chunk_lines[curpos])
      BufferManager.flash "No text chunk under cursor."
      return
    end
    unless HookManager.enabled? "goto"
      BufferManager.flash "You must add a ~/.csup/hooks/goto hook before you can goto a URI."
      return
    end

    # The text line under the cursor either is an array of widgets like this:
    #   [{:text_color, "Some text"}, {:text_color, " continued here"}]
    # or it is a simple string.
    linetext = @text[curpos]
    if linetext.is_a?(WidgetArray)
      # extract the strings from the widgets
      linetext = linetext.map {|w| w[1]}.join("")
    end
    if match = linetext.match(URI.regexp)
      url = match[0]
      # The goto hook reads a line containing the URL, and runs
      # the appropriate viewer.  If there's an error, it sends
      # an error message to stdout
      error_message = nil
      success = HookManager.run("goto") do |pipe|
	pipe.transmit do |f|
	  f.puts url
	end
	pipe.receive do |f|
	  error_message = f.gets
	end
      end
      if !success
	if error_message
	  BufferManager.flash error_message.strip
	else
	  BufferManager.flash "goto hook failed with unknown error"
	end
      end
    else
      BufferManager.flash "No URI found."
    end
  end

  def archive_and_kill(*args); archive_and_then :kill end
  def spam_and_kill(*args); spam_and_then :kill end
  def delete_and_kill(*args); delete_and_then :kill end
  def unread_and_kill(*args); unread_and_then :kill end
  def do_nothing_and_kill(*args); do_nothing_and_then :kill end

  def archive_and_next(*args); archive_and_then :next end
  def spam_and_next(*args); spam_and_then :next end
  def delete_and_next(*args); delete_and_then :next end
  def unread_and_next(*args); unread_and_then :next end
  def do_nothing_and_next(*args); do_nothing_and_then :next end

  def archive_and_prev(*args); archive_and_then :prev end
  def spam_and_prev(*args); spam_and_then :prev end
  def delete_and_prev(*args); delete_and_then :prev end
  def unread_and_prev(*args); unread_and_then :prev end
  def do_nothing_and_prev(*args); do_nothing_and_then :prev end


  def dispatch(op : Symbol, &block)
    return if @dying
    @dying = true

    l = -> do
      block.call	# always assume that a block is given
      BufferManager.kill_buffer_safely buffer
    end

    case op
    when :next
      @index_mode.launch_next_thread_after @thread, &l
    when :prev
      @index_mode.launch_prev_thread_before @thread, &l
    when :kill
      l.call
    else
      raise ArgumentError.new("unknown thread dispatch operation #{op.inspect}")
    end
  end

  def archive_and_then(op : Symbol)
    dispatch(op) do
      undo_thread = @thread	# save thread for the undo block, because @thread might change
      @thread.remove_label :inbox
      Notmuch.save_thread @thread
      #STDERR.puts "archive_and_then about to relay :archived for #{@thread.to_s}"
      UpdateManager.relay self, :archived, @thread 	# .first is bogus!
      UndoManager.register "archiving 1 thread" do
        #STDERR.puts "undoing archive of #{undo_thread.to_s}"
        undo_thread.apply_label :inbox
        Notmuch.save_thread undo_thread
        UpdateManager.relay self, :unarchived, undo_thread
      end
    end
  end

  def spam_and_then(op : Symbol)
    dispatch(op) do
      undo_thread = @thread	# save thread for the undo block, because @thread might change
      @thread.apply_label :spam
      Notmuch.save_thread @thread
      UpdateManager.relay self, :spammed, @thread
      UndoManager.register "marking 1 thread as spam" do
        undo_thread.remove_label :spam
        Notmuch.save_thread undo_thread
        UpdateManager.relay self, :unspammed, undo_thread
      end
    end
  end

  def delete_and_then(op : Symbol)
    dispatch op do
      undo_thread = @thread	# save thread for the undo block, because @thread might change
      @thread.apply_label :deleted
      Notmuch.save_thread @thread
      UpdateManager.relay self, :deleted, @thread
      UndoManager.register "deleting 1 thread" do
        undo_thread.remove_label :deleted
        Notmuch.save_thread undo_thread
        UpdateManager.relay self, :undeleted, undo_thread
      end
    end
  end

  def unread_and_then(op : Symbol)
    dispatch op do
      @thread.apply_label :unread
      Notmuch.save_thread @thread
      UpdateManager.relay self, :labeled, @thread
    end
  end

  def do_nothing_and_then(op)
    dispatch(op) {}
  end

  def pipe_message(*args)
    msgid = ""
    partid = 0
    if (chunk = @chunk_lines[curpos]) && chunk.is_a?(AttachmentChunk)
      msgid = chunk.message.id
      partid = chunk.part.id
    elsif message = @message_lines[curpos]
      msgid = message.id
      partid = 0
    else
      return
    end

    command = BufferManager.ask(:shell, "pipe command: ")
    return if command.nil? || command.empty?

    pipe = Pipe.new(command, [] of String, shell: true)
    output = ""
    exit_status = pipe.start do |p|
      # Send the part data to the command.
      p.transmit do |cmd|
        Notmuch.write_part(msgid, partid) do |part|
          IO.copy(part, cmd)
	end
      end

      # Read the output of the command (should only be present
      # in case of an error).
      p.receive do |cmd|
        output = cmd.gets_to_end
      end
    end

    if exit_status != 0
      BufferManager.flash "Command '#{command}' returned exit status #{exit_status}"
      return
    end

    if output && output.size > 0
      BufferManager.spawn "Output of '#{command}'", TextMode.new(output)
    else
      BufferManager.flash "'#{command}' done!"
    end
  end


  # Old test code.

  def display_thread(thread : MsgThread)
    m = thread.msg
    if m
      display_message(m)
    end
  end

  def display_message(msg : Message, level = 0)
    prefix = "  " * level
    @text << "#{prefix}Message:"
    @text << "#{prefix}  id: #{msg.id}"
    @text << "#{prefix}  filename: #{msg.filename}"
    t = msg.thread
    if t
      @text << "#{prefix}  thread object id: #{t.object_id}"
    else
      @text << "#{prefix}  No containing thread!"
    end
    parent = msg.parent
    if parent
      @text << "#{prefix}  parent id: #{parent.id}"
    end

    @text << "#{prefix}  timestamp: #{msg.timestamp} (#{Time.unix(msg.timestamp)})"
    @text << "#{prefix}  tags: #{msg.tags.join(",")}"
    @text << "#{prefix}  date_relative: #{msg.date_relative}"

    @text << "#{prefix}  headers:"
    msg.headers.each do |k,v|
      @text << "#{prefix}    #{k} = #{v}"
    end

    msg.parts.each do |p|
      @text << "#{prefix}  Part ID #{p.id}, content type #{p.content_type}, filename '#{p.filename}'\n"
      if p.content == ""
	@text << "#{prefix}  Content missing!"
      else
        @text << "#{prefix}  Content:"
        p.content.lines.each {|l| @text << prefix + "    " + l}
      end
    end

    if msg.children.size > 0
      @text << "#{prefix}  Children:"
      msg.children.each do |child|
	display_message(child, level + 2)
      end
    end

  end

  def view(chunk)
    #STDERR.puts "view: chunk type = #{chunk.type}"
    return unless chunk.is_a?(AttachmentChunk)
    BufferManager.flash "viewing #{chunk.part.content_type} attachment..."
    success = chunk.view!
    #STDERR.puts "chunk.view! returned #{success}"
    BufferManager.erase_flash
    BufferManager.completely_redraw_screen
    unless success
      BufferManager.spawn "Attachment: #{chunk.filename}", TextMode.new(chunk.to_s, chunk.filename)
      #BufferManager.flash "Couldn't execute view command, viewing as text."
    end
  end
end

end	# Redwood
