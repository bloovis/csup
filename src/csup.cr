require "ncurses"
require "./config.cr"

LibNCurses.setlocale(0, "")

# TODO: Write documentation for `Csup`
module Csup
  VERSION = "0.1.0"

  # TODO: Put your code here
end

# Add some ncursesw functions not provided by the shard.
lib LibNCurses
  fun get_wch(LibC::Int*) : LibC::Int
end

# initialize
NCurses.init
NCurses.cbreak
NCurses.noecho
# NCurses.start_color

# define background color
#pair = NCurses::ColorPair.new(1).init(NCurses::Color::RED, NCurses::Color::BLACK)
#NCurses.bkgd(pair)

NCurses.erase
# move the cursor
NCurses.move(x: 0, y: 1)
# longname returns the verbose description of the current terminal
NCurses.addstr(NCurses.longname)

NCurses.move(x: 0, y: 2)
NCurses.addstr(NCurses.curses_version)

NCurses.move(y: 10, x: 20)
s = "あいう"
NCurses.addstr("Hello, " + s + "!")
NCurses.refresh

#  NCurses.notimeout(true)
# NCurses.getch
status = LibNCurses.get_wch(out ch)
NCurses.addstr("status = #{status}, ch = #{ch}")
NCurses.refresh
status = LibNCurses.get_wch(pointerof(ch))
#  sleep(5)
NCurses.endwin
