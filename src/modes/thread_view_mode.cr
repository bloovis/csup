require "./line_cursor_mode"

module Redwood

class ThreadViewMode < LineCursorMode
  mode_class help

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
    k.add(:help, "help", "h")
  end

  @text = TextLines.new
  @indent_spaces = 0
  @chunk_lines = SparseArray(Chunk | Message).new
  @message_lines = SparseArray(Message).new
  @person_lines = SparseArray(Person).new

  def lines
    @text.size
  end

  def [](n) : Text
    @text[n]
  end

  def initialize(thread : MsgThread)
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

  ## here we generate the actual content lines. we accumulate
  ## everything into @text, and we set @chunk_lines and
  ## @message_lines, and we update @layout.
  def regen_text
    @text = [] of Text
    @chunk_lines = SparseArray(Chunk | Message).new
    @message_lines = SparseArray(Message).new
    @person_lines = SparseArray(Person).new

    prevm = nil
    @thread.each do |m, depth, parent|
      #unless m.is_a? Message # handle nil and :fake_root
      #  @text += chunk_to_lines m, nil, @text.length, depth, parent
      #  next
      #end
      l = @layout[m]
      #STDERR.puts "regen_text: processing message #{m.id}, layout state #{l.state}"

      ## is this still necessary?
      next unless @layout[m].state # skip discarded drafts

      ## build the patina
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
          cl = @chunk_layout[c]

          ## set the default state for chunks
          cl.state ||=
            if c.expandable? # && c.respond_to?(:initial_state)
              c.initial_state
            else
              :closed
            end

	  #STDERR.puts "About to call chunk_to_lines for chunk #{c.type}"
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
      #STDERR.puts "chunk_to_lines: processing chunk #{chunk.type}"
      #raise "Bad chunk: #{chunk.inspect}" unless chunk.respond_to?(:inlineable?) ## debugging
      if chunk.inlineable?
        #lines = maybe_wrap_text(chunk.lines)	# FIXME
	lines = chunk.lines
	lines.each {|line| ret << [{chunk.color, "#{prefix}#{line}"}]}
      elsif chunk.expandable?
        case state
        when :closed
          ret << [{chunk.patina_color, "#{prefix}+ #{chunk.patina_text}"}]
        when :open
          #lines = maybe_wrap_text(chunk.lines)	# FIXME
	  lines = chunk.lines
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

  def help
    BufferManager.flash "This is the help command."
    #puts "This is the help command."
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

end

end	# Redwood
