# Ncurses functions used by sup that are missing in the NCurses shard.

require "../lib/ncurses/src/ncurses"
require "./util"

# Extend the LibNcurses library.
lib LibNCurses
  alias Wint_t = Int32

  fun getbegx(window : Window) : LibC::Int
  fun getbegy(window : Window) : LibC::Int
  fun get_wch(Wint_t*) : LibC::Int
  fun doupdate : LibC::Int
  fun wnoutrefresh(window : Window) : LibC::Int
  fun COLOR_PAIR(LibC::Int) : LibC::Int
  fun attrset(LibC::Int) : LibC::Int
  fun clrtoeol : LibC::Int
  fun timeout(LibC::Int) : LibC::Int
end

# Ruby ncurses class is called Ncurses (lower-case c)
alias Ncurses = NCurses

module NCurses
  alias Wint_t = LibNCurses::Wint_t

  @@num_colors = 0
  @@max_pairs = 0
  @@mouse_y = 0

  def num_colors
    if @@num_colors = 0
      @@num_colors = `tput colors`.to_i
    end
    return @@num_colors
  end

  def max_pairs
    if @@max_pairs = 0
      @@max_pairs = `tput pairs`.to_i
    end
    return @@max_pairs
  end

  # Wrapper for `get_wch()`
  def get_wch(w : Wint_t) : LibC::Int
    LibNCurses.get_wch(w)
  end

  # Wrapper for `init_pair()`
  def init_pair(slot : LibC::Short, foreground : LibC::Short, background : LibC::Short) : LibC::Int
    LibNCurses.init_pair(slot, foreground, background)
  end

  # Wrapper for `doupdate()`
  def doupdate
    LibNCurses.doupdate
  end

  # Wrapper for `getmaxx`
  def cols
    LibNCurses.getmaxx(stdscr)
  end

  # Wrapper for `getmaxy`
  def rows
    LibNCurses.getmaxy(stdscr)
  end

  # Wrapper for `attrset`
  def attrset(attr : LibC::Int) : LibC::Int
    LibNCurses.attrset(attr)
  end

  # Wrapper for `mvaddstr`
  def mvaddstr(y : LibC::Int, x : LibC::Int, str : String) : LibC::Int
    LibNCurses.mvwaddstr(stdscr, y, x, str.to_unsafe)
  end

  # Set the cursor state
  # Use `Cursor` enum
  # Wrapper for `curs_set()`
  def curs_set(visibility : LibC::Int) : LibC::Int
    LibNCurses.curs_set(Cursor.new(visibility))
  end

  # Wrapper for `clrtoeol`
  def clrtoeol : LibC::Int
    LibNCurses.clrtoeol
  end

  # Wrapper for `endwin`
  def endwin : LibC::Int
    LibNCurses.endwin
  end

  # Wrapper for `timeout`
  def timeout(delay : LibC::Int) : LibC::Int
    LibNCurses.timeout(delay)
  end

  A_NORMAL = 0
  A_BOLD = 0x200000
  A_BLINK = 0x80000
  BUTTON1_CLICKED = 0x4
  BUTTON1_DOUBLE_CLICKED = 0x8
  COLOR_DEFAULT = -1
  COLOR_BLACK = 0x0
  COLOR_RED = 0x1
  COLOR_GREEN = 0x2
  COLOR_YELLOW = 0x3
  COLOR_BLUE = 0x4
  COLOR_MAGENTA = 0x5
  COLOR_CYAN = 0x6
  COLOR_WHITE = 0x7
#  ERR = 0xffffffffffffffff
  KEY_CANCEL = 0x163

  # Keycodes
  KEY_CODE_YES = 0x100
  KEY_MOUSE = 0x199
  KEY_ENTER = 0x157
  KEY_BACKSPACE = 0x107
  KEY_UP = 0x103
  KEY_DOWN = 0x102
  KEY_LEFT = 0x104
  KEY_RIGHT = 0x105
  KEY_PPAGE = 0x153
  KEY_NPAGE = 0x152
  KEY_HOME = 0x106
  KEY_END = 0x168
  KEY_IC = 0x14b
  KEY_DC = 0x14a
  KEY_F1 = 0x109
  KEY_F2 = 0x10a
  KEY_F3 = 0x10b
  KEY_F4 = 0x10c
  KEY_F5 = 0x10d
  KEY_F6 = 0x10e
  KEY_F7 = 0x10f
  KEY_F8 = 0x110
  KEY_F9 = 0x111
  KEY_F10 = 0x112
  KEY_F11 = 0x113
  KEY_F12 = 0x114
  KEY_F13 = 0x115
  KEY_F14 = 0x116
  KEY_F15 = 0x117
  KEY_F16 = 0x118
  KEY_F17 = 0x119
  KEY_F18 = 0x11a
  KEY_F19 = 0x11b
  KEY_F20 = 0x11c
  KEY_RESIZE = 0x19a

#  OK = 0x0
  REPORT_MOUSE_POSITION = 0x10000000

  @@func_keynames = {
    KEY_BACKSPACE => "C-h",
    KEY_RESIZE => "C-l",
    KEY_IC => "Insert",
    KEY_DC => "Delete",
    KEY_UP => "Up",
    KEY_DOWN => "Down",
    KEY_LEFT => "Left",
    KEY_RIGHT => "Right",
    KEY_PPAGE => "PgUp",
    KEY_NPAGE => "PgDn",
    KEY_HOME => "Home",
    KEY_END => "End",
    KEY_F1 => "F1",
    KEY_F2 => "F2",
    KEY_F3 => "F3",
    KEY_F4 => "F4",
    KEY_F5 => "F5",
    KEY_F6 => "F6",
    KEY_F7 => "F7",
    KEY_F8 => "F8",
    KEY_F9 => "F9",
    KEY_F10 => "F10",
    KEY_F11 => "F11",
    KEY_F12 => "F12",
    KEY_F13 => "F13",
    KEY_F14 => "F14",
    KEY_F15 => "F15",
    KEY_F16 => "F16",
    KEY_F17 => "F17",
    KEY_F18 => "F18",
    KEY_F19 => "F19",
    KEY_F20 => "F20"
  }

  macro consts(*names)
    @@consts = {
    {% for name in names %}
      {{name.stringify}} => {{name.id}},
    {% end %}
    }
  end
  consts A_BOLD, COLOR_DEFAULT, COLOR_BLACK, COLOR_RED, COLOR_GREEN,
         COLOR_YELLOW, COLOR_BLUE, COLOR_MAGENTA, COLOR_CYAN,
	 COLOR_WHITE

  # Ugly hack to make sup's colormap code happy.
  def const_get(name : String) : Int32
    if @@consts.has_key?(name)
      return @@consts[name]
    else
      raise NameError.new("no such Ncurses constant #{name}")
      return 0
    end
  end

  def keyname(ch : Int32, function_key = false) : String
    # Ncurses.print("keyname: ch #{sprintf("0x%x", ch)}, function_key #{function_key}\n")
    if function_key
      if @@func_keynames.has_key?(ch)
	return @@func_keynames[ch]
      else
	return sprintf("F-%x", ch)
      end
    else
      if ch >= 0x00 && ch <= 0x1f
	return "C-#{(ch + 0x60).chr}"
      else
	return ch.chr.to_s
      end
    end
  end

  # Get a keystroke and return a string representation:
  #  printable key: one-character string containg the key
  #  ctrl-key:  C-<lowercase-key>
  #  alt-key;   M-<lowercase-key>
  #  ctrl-alt-key: C-M-<lowercase-key>
  #  function key: name of key ("F1", "End", "Insert", "PgDn", etc.)
  protected def do_getkey(prefix = "") : String
    if (result = LibNCurses.get_wch(out ch)) == ERR
      return "ERR"
    end
    if result == Ncurses::KEY_CODE_YES
      if ch == KEY_MOUSE
        if mouse = NCurses.get_mouse
          @@mouse_y = mouse.coordinates[:y]
	  if mouse.state.includes?(Mouse::B1DoubleClicked)
	    return "doubleclick"
	  elsif mouse.state.includes?(Mouse::B1Clicked)
	    return "click"
	  end
	end
	return "click"
      else
	return prefix + keyname(ch, true)
      end
    else
      if ch == 0x1b
	return do_getkey("M-")
      elsif ch == 0x1c
        return do_getkey("C-M")
      elsif ch == 0x1e
        return do_getkey("C-")
      else
	return prefix + keyname(ch, false)
      end
    end
  end

  # Get a key, or return "ERR" if a timeout occurs.  `delay` specifies
  # the timeout value in milliseconds, or -1 (default) to disable the timeout.
  def getkey(delay = -1)
    timeout(delay)
    s = do_getkey
    timeout(-1)
    return s
  end

  def getmouse_y
    @@mouse_y
  end

  class Window
    # Set a window's attributes
    #
    # Wrapper for `wattrset()` (`attrset()`)
    def attrset(attr)
      LibNCurses.wattrset(self, Attribute.new(attr.to_u32))
    end

    # Add string to window and move cursor
    #
    # Wrapper for `mvwaddstr()` (`mvaddstr()`)
    def mvaddstr(y, x, str)
      raise "mvwaddstr error y=#{y} x=#{x} str='#{str}'" if LibNCurses.mvwaddstr(self, y, x, str.to_unsafe) == ERR
    end

    # Copy window to virtual screen
    #
    # Wrapper for `wnoutrefresh()` (`noutrefresh()`)
    def noutrefresh
      raise "wnoutrefresh error" if LibNCurses.wnoutrefresh(self) == ERR
    end

  end	# Window

end	# NCurses

module Redwood

  @@cursing = false

  def self.start_cursing
    Ncurses.start
    Ncurses.cbreak
    Ncurses.no_echo
    #Ncurses.stdscr.keypad 1
    Ncurses.keypad(true)	# Handle function keys and arrows
    Ncurses.raw
    Ncurses.nonl		# don't translate Enter to C-J on input
    Ncurses.curs_set 0
    Ncurses.start_color
    Ncurses.use_default_colors
    if Config.bool(:mouse)
      NCurses.mouse_mask(NCurses::Mouse::AllEvents | NCurses::Mouse::Position)
    end
    #Ncurses.prepare_form_driver
    @@cursing = true
  end

  def self.stop_cursing
    return unless @@cursing
    Ncurses.curs_set 1
    Ncurses.echo
    Ncurses.end
    @@cursing = false
  end

  def self.cursing
    @@cursing
  end

end	# Redwood
