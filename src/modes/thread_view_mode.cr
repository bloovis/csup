require "./line_cursor_mode"
require "./text_mode"

module Redwood

class ThreadViewMode < LineCursorMode
  mode_class expand_all_quotes, expand_all_messages, activate_chunk,
	     align_current_message, toggle_detailed_header,
	     jump_to_next_and_open, jump_to_prev_and_open,
	     jump_to_next_open, jump_to_prev_open,
	     archive_and_kill, do_nothing_and_kill,
	     archive_and_next, do_nothing_and_next,
	     archive_and_prev, do_nothing_and_prev

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
    k.add :activate_chunk, "Expand/collapse or activate item", "C-m"
    k.add :expand_all_messages, "Expand/collapse all messages", 'E'
    k.add :expand_all_quotes, "Expand/collapse all quotes in a message", 'o'
    k.add :jump_to_next_open, "Jump to next open message", 'n'
    k.add :jump_to_next_and_open, "Jump to next message and open", "C-n"
    k.add :jump_to_prev_open, "Jump to previous open message", 'p'
    k.add :jump_to_prev_and_open, "Jump to previous message and open", "C-p"
    k.add :align_current_message, "Align current message in buffer", 'z'
    k.add_multi "(a)rchive/(d)elete/mark as (s)pam/mark as u(N)read:", '.' do |kk|
      kk.add :archive_and_kill, "Archive this thread and kill buffer", 'a'
      kk.add :do_nothing_and_kill, "Just kill this buffer", '.'
    end
    k.add_multi "(a)rchive/(d)elete/mark as (s)pam/mark as u(N)read/do (n)othing:", ',' do |kk|
      kk.add :archive_and_next, "Archive this thread and view next", 'a'
      kk.add :do_nothing_and_next, "Kill buffer, and view next", 'n', ','
    end
    k.add_multi "(a)rchive/(d)elete/mark as (s)pam/mark as u(N)read/do (n)othing:", ']' do |kk|
      kk.add :archive_and_prev, "Archive this thread, kill buffer, and view previous", 'a'
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

  def toggle_detailed_header(*args)
    return unless m = @message_lines[curpos]
    @layout[m].state = (@layout[m].state == :detailed ? :open : :detailed)
    update
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
      header_lines = headers.map {|k,v| prefix + "   #{k}: #{v}"}
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
      # lines can apparently be both String and Array, convert to Array for map.
      if lines.is_a? String
        lines = lines.lines.to_a
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
  def activate_chunk(*args)
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

  def archive_and_kill(*args); archive_and_then :kill end
  def do_nothing_and_kill(*args); do_nothing_and_then :kill end

  def archive_and_next(*args); archive_and_then :next end
  def do_nothing_and_next(*args); do_nothing_and_then :next end

  def archive_and_prev(*args); archive_and_then :prev end
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
      #STDERR.puts "archive_and_then about to relay :archived for #{@thread.to_s}"
      UpdateManager.relay self, :archived, @thread 	# .first is bogus!
      Notmuch.save_thread @thread
      UndoManager.register "archiving 1 thread" do
        #STDERR.puts "undoing archive of #{undo_thread.to_s}"
        undo_thread.apply_label :inbox
        Notmuch.save_thread undo_thread
        UpdateManager.relay self, :unarchived, undo_thread
      end
    end
  end

  def do_nothing_and_then(op)
    dispatch(op) {}
  end

  def select_item
    l = curpos
    s = String.build do |s|
      s << "Line #{l}: from "
      m = @message_lines[l]
      if m
	s << m.from.email
      else
	s << "nobody"
      end
      s << ", chunk "
      c = @chunk_lines[l]
      if c
	if c.is_a?(Message)
	  s << "msg from " + c.from.email
	else
	  s << c.type
	end
      end
      s << ", person "
      p = @person_lines[l]
      if p
	s << p.email
      else
	s << "nobody"
      end
    end
    BufferManager.flash s
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
