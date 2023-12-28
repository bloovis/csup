require "../lib/ncurses/src/ncurses"

require "../src/supcurses"

Ncurses.start
Ncurses.cbreak
Ncurses.no_echo
Ncurses.keypad(true)	# Handle function keys and arrows
Ncurses.raw
Ncurses.nonl	# don't translate Enter to C-J on input

Ncurses.start_color
Ncurses.use_default_colors
Ncurses.print "COLORS = #{LibNCurses.colors}\n"
Ncurses.print "COLOR_PAIRS = #{LibNCurses.color_pairs}\n"
Ncurses.print "COLOR_PAIR(0) = #{LibNCurses.COLOR_PAIR(0)}\n"
Ncurses.init_pair(1, 3, -1)
yellow = LibNCurses.COLOR_PAIR(1)
Ncurses.print "COLOR_PAIR(1) = #{yellow}\n"
Ncurses.init_pair(10, 4, 5)
Ncurses.print "COLOR_PAIR(10) = #{LibNCurses.COLOR_PAIR(10)}\n"
Ncurses.print "A_BOLD = #{sprintf("%0x", Ncurses::A_BOLD)}\n"
red = Ncurses.const_get("COLOR_RED")
Ncurses.print "COLOR_RED = #{red}\n"
begin
  none = Ncurses.const_get("COLOR_NONE")
  Ncurses.print "COLOR_NONE = #{none}\n"
rescue NameError
  Ncurses.print "No such constant COLOR_NONE\n"
end
Ncurses.print "KEY_ENTER = #{sprintf("%0x", Ncurses::KEY_ENTER)}\n"
Ncurses.print "rows = #{Ncurses.rows}, cols = #{Ncurses.cols}\n"
err = Ncurses.doupdate
Ncurses.print "doupdate returned #{err}"
w = Ncurses.stdscr
w.attrset(yellow)
w.mvaddstr(39, 0, "Test of attrset and mvaddstr.  This text should be yellow.")
w.attrset(Ncurses::A_BLINK)
w.mvaddstr(40, 0, "Test of attrset and mvaddstr.  This text should be blinking.")
w.attrset(Ncurses::A_NORMAL)
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
