---
weight: 6
---

# Ncurses

Sup uses the Ruby `ncursesw` gem as the library for screen and keyboard access.
Rather than attempting to port this gem to Crystal, I chose to use the
`SamualLB/ncurses` shard on github, which provides similar functionality.
In order to make it easier to port the existing Sup code that used `ncursesw`,
I wrote an interface library that wraps the `ncurses` shard in a way that makes
it look like the `ncursesw` gem.  See the source file `src/supcurses.cr` for details.

There are a few differences in the way Csup uses ncurses, as compared with Sup.
The biggest difference is in how Csup handles keyboard and mouse events.
In Sup, this is quite complicated,
because regular keys have to be distinguished from function keys.  Mouse events
add a further complication.

In Csup, I chose to simplify the keyboard interface by providing an `Ncurses.getkey`
method that handles all keyboard and mouse events, and returns a string
for each event.  In the case of ordinary keys, the string is a single character
containing the ASCII key.  For function keys, the string is the name
of the key.  For Ctrl key combos, the string is "C-x", where "x" is the key.
For Alt+Ctrl key combos, the string is "M-C-x", where "x" is the key.
For mouse events, the string is either "click" or "doubleclick"; commands
that bind to these strings must call `Ncurses.getmouse_y` to get the line number.

This scheme simplifies the key binding tables, which can now refer to the key
or mouse event with a string.

The `Ncurses.getkey` method takes an optional timeout parameter; if present,
it specifies the number of seconds to wait for a keyboard or mouse event.
If the timeout occurs, `getkey` returns the string "ERR".  Csup uses
this feature to handle the `poll_interval` option in `~/.csup/config.yaml`.
If Csup receives "ERR" at the main command prompt, it runs the poll command,
which is also bound to "P".
