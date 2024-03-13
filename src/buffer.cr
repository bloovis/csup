require "./singleton"
require "./colormap"
require "./opts"
require "./mode"
require "./util"
require "./modes/file_browser_mode"
require "system/user"
require "./modes/completion_mode"

module Redwood

# class InputSequenceAborted < StandardError; end

class Buffer
  getter x : Int32
  getter y : Int32
  getter width : Int32
  getter height : Int32
  getter title : String
  getter atime : Time
  getter mode : Mode
  getter w : Ncurses::Window
  property force_to_top : Bool
  bool_getter :system, :dirty
  bool_property :hidden

  def initialize(@w, @mode, @width, @height, opts = Opts.new)
    @dirty = true
    @focus = false
    @title = opts.str(:title) || ""
    @force_to_top = opts.bool(:force_to_top) || false
    @hidden = opts.bool(:hidden) || false
    @x = @y = 0
    @atime = Time.unix 0
    @system = opts.bool(:system) || false
  end

  def content_height; @height - 1; end
  def content_width; @width; end

  def resize(rows, cols)
    return if cols == @width && rows == @height
    @width = cols
    @height = rows
    @dirty = true
    mode.resize rows, cols
  end

  def redraw(status)
    if @dirty
      draw status
    else
      draw_status status
    end
    commit
  end

  def mark_dirty; @dirty = true; end

  def commit
    @dirty = false
    @w.noutrefresh
  end

  def draw(status)
    #STDERR.puts "Buffer.draw, caller #{caller[1]}"
    @mode.draw
    draw_status status
    commit
    @atime = Time.local
  end

  ## s nil means a blank line!
  def write(y, x, s, opts = Opts.new)
    return if x >= @width || y >= @height

    @w.attrset Colormap.color_for(opts.sym(:color) || :none, opts.bool(:highlight))
    s ||= ""
    maxl = @width - x # maximum display width width

    # fill up the line with blanks to overwrite old screen contents
    @w.mvaddstr(y, x, " " * maxl) unless opts.bool(:no_fill)

    @w.mvaddstr y, x, s.slice_by_display_length(maxl)
  end

  def clear
    @w.clear
  end

  def draw_status(status : String)
    write @height - 1, 0, status, Opts.new({:color => :status_color})
  end

  def focus
    @focus = true
    @dirty = true
    @mode.focus
  end

  def blur
    @focus = false
    @dirty = true
    @mode.blur
  end
end

class BufferManager
  singleton_class

  ## we have to define the key used to continue in-buffer search here, because
  ## it has special semantics that BufferManager deals with---current searches
  ## are canceled by any keypress except this one.
  CONTINUE_IN_BUFFER_SEARCH_KEY = "n"
  KEY_CANCEL = "C-g"

  @focus_buf : Buffer | Nil
  @flash : String?
  @users : Array(String)?

  def initialize
    singleton_pre_init
    #puts "BufferManager.initialize"

    @name_map = Hash(String, Buffer).new
    @buffers = Array(Buffer).new
    @focus_buf = nil
    @dirty = true
    @minibuf_stack = Hash(Int32, String).new
    # @minibuf_mutex = Mutex.new
    # @textfields = {}
    @flash = nil
    @shelled = @asking = false
    @in_x = ENV["TERM"] =~ /(xterm|rxvt|screen)/
    @sigwinch_happened = false
    #@sigwinch_mutex = Mutex.new

    singleton_post_init
  end
    
  def focus_on(buf : Buffer)
    return unless @buffers.index(buf)
    return if buf == @focus_buf
    f = @focus_buf
    if f
      f.blur
    end
    @focus_buf = buf
    if buf
      buf.focus
    end
  end

  def buffers : Array(Tuple(String, Buffer))
    @name_map.to_a
  end
  singleton_method buffers

  def raise_to_front(buf : Buffer)
    #puts "raise_to_front before delete"
    return unless @buffers.delete(buf)
    #puts "raise_to_front after delete"
    if @buffers.size > 0 && @buffers.last.force_to_top
      @buffers.insert(-2, buf)
    else
      #puts "raise_to_front pushing buf"
      @buffers.push buf
    end
    focus_on @buffers.last
    @dirty = true
    draw_screen
  end
  singleton_method raise_to_front, buf

  ## we reset force_to_top when rolling buffers. this is so that the
  ## human can actually still move buffers around, while still
  ## programmatically being able to pop stuff up in the middle of
  ## drawing a window without worrying about covering it up.
  ##
  ## if we ever start calling roll_buffers programmatically, we will
  ## have to change this. but it's not clear that we will ever actually
  ## do that.
  def roll_buffers(*args)
    #@name_map.each {|name, buf| STDERR.puts "roll: name #{name}"}
    bufs = rollable_buffers
    bufs.last.force_to_top = false
    raise_to_front bufs.first
  end
  singleton_method roll_buffers

  def roll_buffers_backwards(*args)
    bufs = rollable_buffers
    return unless bufs.length > 1
    bufs.last.force_to_top = false
    raise_to_front bufs[bufs.length - 2]
  end
  singleton_method roll_buffers_backwards

  def rollable_buffers
    @buffers.select { |b| !(b.system || b.hidden) || @buffers.last == b }
  end

  def handle_input(c : String)
    b = @focus_buf
    if b
      m = b.mode
      if m
        if m.in_search? && c != CONTINUE_IN_BUFFER_SEARCH_KEY
          m.cancel_search!
          b.mark_dirty
	end
	m.handle_input(c)
      else
	STDERR.puts "Buffer has no mode!"
      end
    else
      STDERR.puts "BufferManager.handle_input: no focus_buf!"
    end
  end
  singleton_method handle_input, c

  ## requires the mode to have #done? and #value methods
  def spawn_modal(title : String, mode : Mode, opts = Opts.new)
    b = spawn title, mode, opts
    draw_screen

    until mode.done?
      c = Ncurses.getkey
      break if c == KEY_CANCEL
      mode.handle_input c
      draw_screen
      erase_flash
    end

    kill_buffer b
    mode.value
  end
  singleton_method spawn_modal, title, mode, opts

  def kill_all_buffers_safely
    until @buffers.empty?
      ## inbox mode always claims it's unkillable. we'll ignore it.
      return false unless @buffers.last.mode.is_a?(InboxMode) || @buffers.last.mode.killable?
      kill_buffer @buffers.last
    end
    true
  end
  singleton_method kill_all_buffers_safely

  def kill_buffer_safely(buf)
    if buf
      return false unless buf.mode.killable?
      kill_buffer buf
      true
    else
      false
    end
  end
  singleton_method kill_buffer_safely, buf

  def kill_all_buffers
    until @buffers.empty?
      kill_buffer @buffers.first
    end
  end
  singleton_method kill_all_buffers

  def kill_buffer(buf)
    raise ArgumentError.new("buffer not on stack: #{buf}: #{buf.title.inspect}") unless @buffers.member? buf

    #STDERR.puts "kill_buffer: calling #{buf.mode.name}.cleanup"
    buf.mode.cleanup
    @buffers.delete buf
    @name_map.delete buf.title
    @focus_buf = nil if @focus_buf == buf
    if @buffers.empty?
      ## TODO: something intelligent here
      ## for now I will simply prohibit killing the inbox buffer.
    else
      raise_to_front @buffers.last
    end
  end
  singleton_method kill_buffer, buf

  ## for simplicitly, we always place the question at the very bottom of the
  ## screen.
  # Crystal note: we don't use TextField or Ncurses forms, so ignore
  # then domain parameter, but allow it for compatibility with existing code.

  alias AskBlock = Proc(String, Array(Tuple(String, String)))

  def do_ask(domain : Symbol, question : String, block_given? = true,
	     default=nil, &block : AskBlock) : String?
    #STDERR.puts "ask: domain #{domain}, question '#{question}', default '#{default}'"
    raise "impossible!" if @asking
    raise "Question too long" if Ncurses.cols <= question.size
    @asking = true
    status, title = get_status_and_title(@focus_buf)
    draw_screen Opts.new({:sync => false, :status => status, :title => title})
    row = Ncurses.rows - 1
    leftcol = question.size
    fillcols = Ncurses.cols - leftcol
    Ncurses.mvaddstr(row, 0, question)
    Ncurses.move(row, leftcol)
    Ncurses.clrtoeol
    Ncurses.curs_set 1
    Ncurses.refresh

    ret = default || ""
    pos = ret.size
    done = false
    aborted = false
    completion_buf = nil
    completion_mode = nil
    lastc = ""
    until done
      # Don't let ret exceed the number of columns available.
      if ret.size >= fillcols-1
	ret = ret[0...fillcols-1]
      end

      # CompletionMode changes the color to blue for its status line,
      # reset to the normal color.
      Ncurses.attrset Colormap.color_for(:text_color)

      # Redraw the ret buffer.
      Ncurses.mvaddstr(row, leftcol, ret + (" " * (fillcols - ret.size)))
      Ncurses.move(row, leftcol + pos)
      Ncurses.refresh

      c = Ncurses.getkey
      next if c == ""
      case c
      when "C-a"
        pos = 0
      when "C-e"
        pos = ret.size
      when "Left", "C-b"
        if pos > 0
	  pos -= 1
	end
      when "Right", "C-f"
        if pos < ret.size
	  pos += 1
	end
      when "C-h", "Delete", "C-d"
        if !(c == "C-h" && pos == 0)
	  if c == "C-h"
	    pos -= 1
	  end
	  left = (pos == 0) ? "" : ret[0..pos-1]
	  right = (pos >= ret.size - 1) ? "" : ret[pos+1..]
	  ret = left + right
	end
      when "C-k"
        if pos == 0
	  ret = ""
	else
	  ret = ret[0..pos-1]
	end
      when "C-u"
        ret = ""
	pos = 0
      when "C-m"
        done = true
      when KEY_CANCEL
	done = true
	aborted = true
      when "C-i"
        pos = ret.size
        if lastc == "C-i"
	  if completion_mode
	    completion_mode.roll
	    draw_screen(Opts.new({:skip_minibuf => true}))
	  end
	else
	  comps = yield(ret)
	  #STDERR.puts "#{comps.size} completions returned by block: "
	  #comps.each do |t|
	    #STDERR.puts "  full #{t[0]}, short #{t[1]}"
	  #end
	  if comps.size > 0
	    ret = comps.map { |t| t[0] }.shared_prefix(true)	# t[0] = full
	    pos = ret.size
	    shorts = comps.map { |t| t[1] }			# t[1] = short
	    kill_buffer(completion_buf) if completion_buf
	    prefix_len = shorts.shared_prefix(caseless=true).size
	    completion_mode = CompletionMode.new(shorts,
				      Opts.new({:header => "Possible completions for \"#{ret}\": ",
						:prefix_len => prefix_len}))
	    completion_buf = spawn("<completions>", completion_mode, Opts.new({:height => 10}))
	    draw_screen(Opts.new({:skip_minibuf => true}))
	  end
	end
      else
	if c.size == 1
	  ret = ret.insert(pos, c)
	  pos += 1
	end
      end
      lastc = c
    end

    kill_buffer(completion_buf) if completion_buf
    @asking = false
    Ncurses.curs_set 0
    draw_screen Opts.new({:sync => false, :status => status, :title => title})

    if aborted
      return nil
    else
      return ret
    end
  end

  # This variant expects a completions block.
  def self.ask(domain : Symbol, question : String, default=nil)
    self.instance.do_ask(domain, question, true, default) {|s| yield s }
  end

  # This variant does NOT expect a completions block.
  def self.ask(domain : Symbol, question : String, default=nil)
    self.instance.do_ask(domain, question, false, default) {|s| [{"", ""}]}
  end

  def ask_with_completions(domain, question, completions, default=nil) : String?
    do_ask domain, question, true, default do |s|
    #  s.fix_encoding!
      completions.select { |x| x =~ /^#{Regex.escape s}/i }.map { |x| {x, x} }
    end
  end
  singleton_method ask_with_completions, domain, question, completions, default

  def ask_many_emails_with_completions(domain : Symbol, question : String,
			               completions : Array(String),
				       default=nil) : String?
    do_ask(domain, question, true, default) do |partial|
      prefix, target = partial.split_on_commas_with_remainder
      target ||= prefix.pop || ""
      #target.fix_encoding!

      prefix = prefix.join(", ") + (prefix.empty? ? "" : ", ")
      #prefix.fix_encoding!

      completions.select { |x| x =~ /^#{Regex.escape target}/i }.
		  sort_by { |c| {ContactManager.contact_for(c) ? 0 : 1, c} }.
		  map { |x| {prefix + x, x} }
    end
  end
  singleton_method ask_many_emails_with_completions, domain, question, completions, default

  def ask_many_with_completions(domain : Symbol, question : String,
				completions : Array(String),
				default=nil) : String?
    do_ask domain, question, true, default do |partial|
      STDERR.puts "ask_many_with_completions, partial #{partial}"
      prefix, target =
        case partial
        when /^\s*$/
          ["", ""]
        when /^(.*\s+)?(.*?)$/
          [$1 || "", $2]
        else
          raise "william screwed up completion: #{partial.inspect}"
        end

      #prefix.fix_encoding!
      #target.fix_encoding!
      completions.select { |x| x =~ /^#{Regex.escape target}/i }.map { |x| {prefix + x, x} }
    end
  end
  singleton_method ask_many_with_completions, domain, question, completions, default

  ## returns a set of labels
  def ask_for_labels(domain : Symbol, question : String,
		     default_labels : Set(String),
		     forbidden_labels = Set(String).new) : Set(String)?
    default_labels = default_labels - forbidden_labels - LabelManager::RESERVED_LABELS
    default = default_labels.to_a.sort.join(" ")
    default += " " unless default.empty?
    #STDERR.puts "default = #{default}"

    # here I would prefer to give more control and allow all_labels instead of
    # user_defined_labels only
    applyable_labels = (LabelManager.user_defined_labels - forbidden_labels).
			to_a.sort_by { |s| s.downcase }

    answer = ask_many_with_completions domain, question, applyable_labels, default
    return nil unless answer

    user_labels = Set.new(answer.split)
    user_labels.each do |l|
      if forbidden_labels.includes?(l) || LabelManager::RESERVED_LABELS.includes?(l)
        BufferManager.flash "'#{l}' is a reserved label!"
        return user_labels
      end
    end
    return user_labels
  end
  singleton_method ask_for_labels, domain, question, default_labels, forbidden_labels

  # Ask for contact names, return an array of email addresses, one for each contact.
  # If a name doesn't have a contact, it is assumed to be an email address and
  # is returned unchanged.  Default, if present, is a string of comma-separated
  # email addresses to use if the user enters nothing.
  def ask_for_contacts(domain : Symbol, question : String, default = "") : Array(String)?
    default += " " unless default == ""

    recent = Notmuch.load_contacts(AccountManager.user_emails, 10).map { |c| [c.full_address, c.email] }
    contacts = Array(String).new
    ContactManager.contacts.each do |c|
      if a = ContactManager.alias_for(c)
	contacts << a
      end
      if f = c.full_address
	contacts << f
      end
      if e = c.email
	contacts << e
      end
    end

    completions = (recent + contacts).flatten.uniq
    #completions += HookManager.run("extra-contact-addresses") || []

    answer = BufferManager.ask_many_emails_with_completions(domain, question, completions, default)
    if answer && answer.size > 0
      email_list = Array(String).new
      answer.split_on_commas.each do |x|
        if email = (ContactManager.email_for(x) || x)
	  email_list << email
	end
      end
      return email_list
    else
      return nil
    end
  end
  singleton_method ask_for_contacts, domain, question, default

  def ask_for_account(domain : Symbol, question : String) : String?
    completions = AccountManager.user_emails
    answer = BufferManager.ask_many_emails_with_completions domain, question, completions, ""
    if answer && answer == "" && (acct = AccountManager.default_account)
      answer = acct.email
    end
    return answer
  end
  singleton_method ask_for_account, domain, question

  def ask_getch(question : String, accept_string = "") : String
    # If we're not in Ncurses mode, prompt on the terminal and read
    # a line containing the string representing the keystroke.
    # This is useful for testing purposes only.
    unless Redwood.cursing
      print question
      answer = gets || ""
      return answer.strip
    end

#    Ncurses.print question
#    Ncurses.getkey
    raise "impossible!" if @asking

    accept = accept_string.split("")

    status, title = get_status_and_title(@focus_buf)
    #Ncurses.sync do
      draw_screen Opts.new({:sync => false, :status => status, :title => title})
      Ncurses.mvaddstr Ncurses.rows - 1, 0, question
      Ncurses.move Ncurses.rows - 1, question.size + 1
      Ncurses.curs_set 1
      Ncurses.refresh
    #end

    @asking = true
    ret = ""
    done = false
    until done
      key = Ncurses.getkey
      next if key == ""
      if key == KEY_CANCEL
        done = true
      elsif accept_string == "" || accept.index(key)
        ret = key
        done = true
      end
    end

    @asking = false
    #Ncurses.sync do
      Ncurses.curs_set 0
      draw_screen Opts.new({:sync => false, :status => status, :title => title})
    #end

    ret
  end
  singleton_method ask_getch, help

  ## returns true (y), false (n), or nil (ctrl-g / cancel)
  def ask_yes_or_no(question : String)
    case(r = ask_getch question, "ynYN")
    when "y", "Y"
      true
    when ""
      nil
    else
      false
    end
  end
  singleton_method ask_yes_or_no, question

  def ask_for_filename(domain : Symbol, question : String, default=nil, allow_directory=false) : String?
    answer = do_ask domain, question, true, default do |s|
      if s =~ /(~([^\s\/]*))/ # twiddle directory expansion
        full = $1
	name = $2
	if name.empty?
	  dir = Path.home.to_s
	else
	  if u = System::User.find_by?(name: name)
	    dir = u.home_directory
	  else
	    dir = nil
	  end
	end
        if dir
          [{s.sub(full, dir), "~#{name}"}]
        else
          users.select { |u| u =~ /^#{Regex.escape name}/ }.map do |u|
            {s.sub("~#{name}", "~#{u}"), "~#{u}"}
          end
        end
      else # regular filename completion
        Dir["#{s}*"].sort.map do |fn|
          suffix = File.directory?(fn) ? "/" : ""
          {fn + suffix, File.basename(fn) + suffix}
        end
      end
    end

    if answer
      # Strip single quotes to allow filenames to be dragged and dropped
      # from file browsers like Mate Caja.  Also strip leading and trailing spaces.
      answer = answer.lstrip("' ").rstrip("' ")

      answer =
        if answer.empty?
          spawn_modal "file browser", FileBrowserMode.new
        elsif File.directory?(answer) && !allow_directory
          spawn_modal "file browser", FileBrowserMode.new(answer)
        else
	  # Replace ~name/ or ~/ with actual directory name.
          answer.untwiddle
        end
    end
    return answer
  end
  singleton_method ask_for_filename, domain, question, default, allow_directory

  def resolve_input_with_keymap(c : String, keymap : Keymap) : Symbol | Nil
    #STDERR.puts "resolve_input_with_keymap: c #{c}, keymap #{keymap.object_id}"
    action, text = keymap.action_for c
    #STDERR.puts "resolve_input_with_keymap: action for c is #{action}"
    return nil if action.nil? || text.nil?
    while action.is_a? Keymap # multi-key commands, prompt
      key = BufferManager.ask_getch(text || "")
      if key == "" # user canceled, abort
        erase_flash
        raise "InputSequenceAborted"
      end
      action, text = action.action_for(key) if action.has_key?(key)
    end
    action
  end
  singleton_method resolve_input_with_keymap, c, keymap

  # Return number of lines in minibuf.
  def minibuf_lines : Int32
#    @minibuf_mutex.synchronize do
      [(@flash ? 1 : 0) +
       (@asking ? 1 : 0) +
       @minibuf_stack.size, 1].max
#    end
  end

  # Return array of all minibuf lines, in order by id.
  def minibuf_all : Array(String)
    @minibuf_stack.keys.sort.map {|i| @minibuf_stack[i]}
  end

  def draw_minibuf(refresh = false, sync = false)
    m = Array(String).new
    #@minibuf_mutex.synchronize do
      m = minibuf_all
      f = @flash
      if f
	m << f
      end
      m << "" if m.empty? unless @asking # to clear it
    #end

    #Ncurses.mutex.lock unless opts[:sync] == false
    Ncurses.attrset Colormap.color_for(:text_color)
    adj = @asking ? 2 : 1
    m.each_with_index do |s, i|
      Ncurses.mvaddstr Ncurses.rows - i - adj, 0, s + (" " * [Ncurses.cols - s.size, 0].max)
    end
    Ncurses.refresh if refresh
    #Ncurses.mutex.unlock unless opts[:sync] == false
  end

  def do_say(s : String, id = -1, block_given? = true, &b)
    new_id = id == -1

    #@minibuf_mutex.synchronize do
      if new_id
	if @minibuf_stack.size == 0
	  id = 0
	else
	  id = @minibuf_stack.keys.max + 1
	end
      end
      @minibuf_stack[id] = s
      #puts "Setting minibuf[#{id}] = #{s}"
    #end

    if new_id
      draw_screen Opts.new({:refresh => true})
    else
      draw_minibuf(refresh: true)
    end

    if block_given?
      begin
        #puts "Yielding minibuf id #{id}"
        yield id
      ensure
        #puts "Clearing minibuf[#{id}]"
        clear id
      end
    end
    id
  end

  # Crystal doesn't have block_given? or allow blocks to be optional, so
  # we provide two versions of say, one that requires a block
  # and one that doesn't.
  def self.say(s : String, id = -1)
    self.instance.do_say(s, id, true) {|id| yield id }
  end

  def self.say(s : String, id = -1)
    self.instance.do_say(s, id, false) {}
  end

  def erase_flash; @flash = nil; end
  singleton_method erase_flash

  def flash(s : String)
    if Redwood.cursing
      @flash = s
      draw_screen Opts.new({:refresh => true})
    else
      puts "Buffer flash: " + s
    end
  end
  singleton_method flash, s

  # Deleting a minibuf entry is much simpler in Crystal than in Ruby, because
  # we use hash instead of a sparse array.
  def clear(id : Int32)
    #@minibuf_mutex.synchronize do
      @minibuf_stack.delete(id)
    #end

    draw_screen Opts.new({:refresh => true})
  end
  singleton_method clear, id

  def completely_redraw_screen
    return if @shelled

    ## this magic makes Ncurses get the new size of the screen
    Ncurses.endwin
    Ncurses.stdscr.keypad true
    Ncurses.curs_set 0
    Ncurses.refresh
    #@sigwinch_mutex.synchronize { @sigwinch_happened = false }
    #debug "new screen size is #{Ncurses.rows} x #{Ncurses.cols}"

    draw_screen Opts.new({:clear => true, :refresh => true, :dirty => true, :sync => true})

    # don't know why but a second non-clear draw will resolve some blank screens
    draw_screen Opts.new({:clear => false, :refresh => true, :dirty => true, :sync => true})
  end
  singleton_method completely_redraw_screen

  def draw_screen(opts = Opts.new)
    #minibuf_all.each_with_index {|s, i| Ncurses.print "draw_screen: caller line #{caller_line}, minibuf[#{i}]='#{s}'\n" }
    return if @shelled
    if opts.member? :status
      status = opts.str(:status)
      title = opts.str(:title)
    else
      #raise "status must be supplied if draw_screen is called within a sync" if opts[:sync] == false
      status, title = get_status_and_title @focus_buf # must be called outside of the ncurses lock
    end

    ## http://rtfm.etla.org/xterm/ctlseq.html (see Operating System Controls)
    print "\033]0;#{title}\07" if title && @in_x

    # Ncurses.mutex.lock unless opts[:sync] == false

    buf = @buffers.last
    #STDERR.puts "BufferManager.draw_screen: buffer = #{buf.object_id}, dirty = #{@dirty}"
    buf.resize Ncurses.rows - minibuf_lines, Ncurses.cols
    if @dirty
      buf.draw(status || "")
    else
      buf.redraw(status || "")
    end

    draw_minibuf(sync: false) unless opts.bool(:skip_minibuf)

    @dirty = false
    Ncurses.doupdate
    Ncurses.refresh if opts.bool(:refresh)
    # Ncurses.mutex.unlock unless opts[:sync] == false
  end
  singleton_method draw_screen, opts

  ## if the named buffer already exists, pops it to the front without
  ## calling the block. otherwise, gets the mode from the block and
  ## creates a new buffer. returns two things: the buffer, and a boolean
  ## indicating whether it's a new buffer or not.
  def spawn_unless_exists(title : String, opts=Opts.new, &b : -> Mode)
    new =
      if @name_map.has_key? title
        raise_to_front @name_map[title] unless opts.bool(:hidden)
        false
      else
        mode = b.call
        spawn title, mode, opts
        true
      end
    {@name_map[title], new}
  end
  def self.spawn_unless_exists(title : String, opts=Opts.new, &b : -> Mode)
    self.instance.spawn_unless_exists(title, opts, &b)
  end

  def spawn(title : String, mode : Mode, opts = Opts.new)
    # raise ArgumentError, "title must be a string" unless title.is_a? String
    realtitle = title
    num = 2
    while @name_map.index(realtitle)
      realtitle = "#{title} <#{num}>"
      num += 1
    end

    width = opts.int(:width) || Ncurses.cols
    height = opts.int(:height) || Ncurses.rows - 1
    #system("echo spawn: setting height to #{height}, Ncurses.rows = #{Ncurses.rows} >>/tmp/csup.log")

    ## since we are currently only doing multiple full-screen modes,
    ## use stdscr for each window. once we become more sophisticated,
    ## we may need to use a new Ncurses::WINDOW
    ##
    ## w = Ncurses::WINDOW.new(height, width, (opts[:top] || 0),
    ## (opts[:left] || 0))
    w = Ncurses.stdscr
    b = Buffer.new(w, mode, width, height,
		   Opts.new({:title => realtitle,
			     :force_to_top => opts.bool(:force_to_top) || false,
			     :system => opts.bool(:system) || false}))
    mode.buffer = b
    @name_map[realtitle] = b

    @buffers.unshift b
    if opts.bool(:hidden)
      focus_on(b) unless @focus_buf
    else
      raise_to_front(b)
    end
    b
  end
  singleton_method spawn, title, mode, opts

  private def default_status_bar(buf)
    " [#{buf.mode.name}] #{buf.title}   #{buf.mode.status}"
  end

  private def default_terminal_title(buf)
    "Sup #{Redwood::VERSION} :: #{buf.title}"
  end

  def get_status_and_title(buf)
{% if false %}
    opts = {
      :num_inbox => lambda { Index.num_results_for :label => :inbox },
      :num_inbox_unread => lambda { Index.num_results_for :labels => [:inbox, :unread] },
      :num_total => lambda { Index.size },
      :num_spam => lambda { Index.num_results_for :label => :spam },
      :title => buf.title,
      :mode => buf.mode.name,
      :status => buf.mode.status
    }

    statusbar_text = HookManager.run("status-bar-text", opts) || default_status_bar(buf)
    term_title_text = HookManager.run("terminal-title-text", opts) || default_terminal_title(buf)
{% end %}
    if buf
      return { default_status_bar(buf), default_terminal_title(buf) }
    else
      return { "", "" }
    end
  end

  def focus_buf
    @focus_buf
  end
  singleton_method focus_buf

  def shell_out(command : String, is_gui=false)
    debug "shell out #{command}"
    success = false
    if is_gui
      # no need to save and restore ncurses state
      success = system command
    else
      @shelled = true
      #Ncurses.sync do
        Ncurses.endwin
        success = system command
        Ncurses.stdscr.keypad true
        Ncurses.refresh
        Ncurses.curs_set 0
      #end
      @shelled = false
    end
    success
  end
  singleton_method shell_out, command, is_gui

  def users
    unless u = @users
      u = `getent passwd`.lines.map {|x| x.split(":")[0]}
      @users = u
    end
    u
  end
  singleton_method users

end

end
