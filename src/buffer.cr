require "./singleton"
require "./colormap"
require "./opts"
require "./mode"
require "./util"

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
  property hidden : Bool
  getter system : Bool
  getter dirty : Bool

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

  @focus_buf : Buffer | Nil
  @flash : String?

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
  end
  singleton_method raise_to_front, buf

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
	puts "Buffer has no mode!"
      end
    else
      puts "BufferManager.handle_input: no focus_buf!"
    end
  end
  singleton_method handle_input, c

  ## for simplicitly, we always place the question at the very bottom of the
  ## screen.
  # Crystal note: we don't use TextField or Ncurses forms, so ignore
  # then domain parameter, but allow it for compatiblity with existing code.
  def ask(domain : Symbol, question : String, default=nil) : String
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
    Ncurses.curs_set 1
    Ncurses.refresh

    ret = ""
    done = false
    until done
      c = Ncurses.getkey
      next if c == ""
      case c
      when "C-h"
	if ret.size > 0
	  ret = ret[0..-2]
	end
      when "C-m"
        done = true
      else
	if c.size == 1
	  ret += c
	end
      end
      Ncurses.mvaddstr(row, leftcol, ret + (" " * fillcols))
      Ncurses.move(row, leftcol + ret.size)
      Ncurses.refresh
    end

    @asking = false
    Ncurses.curs_set 0
    draw_screen Opts.new({:sync => false, :status => status, :title => title})

    ret
  end
  singleton_method ask, domain, question, default

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
      if key == "C-g"
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

  def resolve_input_with_keymap(c : String, keymap : Keymap) : Symbol | Nil
    #puts "resolve_input_with_keymap: c #{c}, keymap #{keymap.object_id}"
    action, text = keymap.action_for c
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
    #system("echo do_say: s #{s}, id #{id}, block_given #{block_given?} >>/tmp/csup.log")
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

end

end
