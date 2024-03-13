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

## Keyboard and Mouse

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

## Forms

Sup uses Ncurses forms to implement the "ask" buffer, where users
type an input line in response to a question.  Tab-initiated completions
complicate this code even more.  The result is a very confusing control
flow that switches back and forth between the form handling in `textfield.rb`
and the completion handling in `buffer.rb`.  The following comment by William Morgan
in `textfield.rb` expresses his feelings about this code:

> writing this fucking sucked. if you thought ncurses was some 1970s
> before-people-knew-how-to-program bullshit, wait till you see
> ncurses forms.

Writing the code must have been bad enough, but reading it sucks, too.
So in Csup I chose to eliminate the use of Ncurses forms.  Instead,
I implemented a line buffer editor, which was really not very difficult to write,
and which keeps the control flow all in one place.  See the `do_ask` method
in `src/buffer.cr` for details.

The one feature of Sup's form handling that I didn't implement was
history.  I'm not sure how useful this would be, and I was not even
aware of the feature until I started reading the code.
