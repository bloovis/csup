require "../lib/ncurses/src/ncurses"

require "../src/supcurses"

Ncurses.start
Ncurses.cbreak
Ncurses.no_echo
Ncurses.keypad(true)	# Handle function keys and arrows
Ncurses.raw
Ncurses.nonl	# don't translate Enter to C-J on input

Ncurses.start_color
Ncurses.print "COLOR_PAIRS = #{LibNCurses.color_pairs}\n"
Ncurses.print "A_BOLD = #{sprintf("%0x", Ncurses::A_BOLD)}\n"
Ncurses.print "KEY_ENTER = #{sprintf("%0x", Ncurses::KEY_ENTER)}\n"
err = Ncurses.doupdate
Ncurses.print "doupdate returned #{err}"
w = Ncurses.stdscr
w.attrset(NCurses::Attribute::Blink)
w.mvaddstr(40, 0, "Test of attrset and mvaddstr.  This text should be blinking.")
w.attrset(NCurses::Attribute::Normal)
w.noutrefresh
Ncurses.print "\nPress any key to continue: "
Ncurses.getkey
Ncurses.clear

#while true
#  result = LibNCurses.get_wch(out ch)
#  name = Ncurses.keyname(ch, result == Ncurses::KEY_CODE_YES)
#  Ncurses.print "get_wch returned #{result}, ch #{ch.class.name}, value #{sprintf("0x%x", ch)}, name #{name}\n"
#  break if ch.chr == 'q'
#end

while true
  Ncurses.print "Press any key, or q to exit: "
  ch = Ncurses.getkey
  Ncurses.clear
  Ncurses.print "Got #{ch}\n"
  break if ch == "q"
end

Ncurses.end
