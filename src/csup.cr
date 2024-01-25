require "./keymap"
require "./config"
require "./buffer"
require "./colormap"
require "./search"
require "./undo"
require "./update"
require "./hook"
require "./account"
require "./label"
require "./contact"
require "./modes/inbox_mode"
require "./logger"

module Redwood
  BASE_DIR = File.join(ENV["HOME"], ".csup")

  extend self

  @@log_io : IO?

  def init_managers
    basedir = BASE_DIR

    cf = Config.new(File.join(basedir, "config.yaml"))
    cm = ContactManager.new(File.join(basedir, "contacts.txt"))
    bm = BufferManager.new
    colormap = Colormap.new(File.join(basedir, "colors.yaml"))
    Colormap.reset
    Colormap.populate_colormap
    sm = SearchManager.new(File.join(basedir, "searches.txt"))
    unm = UndoManager.new
    upm = UpdateManager.new
    hm = HookManager.new(File.join(basedir, "hooks"))
    am = AccountManager.new(Config.accounts)
    lm = LabelManager.new(File.join(basedir, "labels.txt"))

    log_io = File.open(File.join(basedir, "log"), "a")
    if log_io
      logm = Logger.new
      Logger.add_sink(log_io)
      @@log_io = log_io
    end
  end

  def event_loop(keymap, &b)
    lmode = Redwood::LogMode.new "system log"
    lmode.on_kill { Logger.clear! }
    Logger.add_sink lmode
    Logger.force_message "Welcome to Sup! Log level is set to #{Logger.level}."

    # The initial draw_screen won't draw the buffer status, because
    # the status is set as a result of calling draw_screen.  Hence,
    # we need to call it again at the beginning of the event loop.
    BufferManager.draw_screen
    while true
      BufferManager.draw_screen
      ch = Ncurses.getkey
      BufferManager.erase_flash
      unless BufferManager.handle_input(ch)
	action = BufferManager.resolve_input_with_keymap(ch, keymap)
	if action
	  send action
	else
	  yield ch
	end
      end
    end
  end

{% if flag?(:MAIN) %}

extend self

actions(quit_now, quit_ask, kill_buffer, roll_buffers, roll_buffers_backwards)

def quit_now
  #BufferManager.say "This is the global quit command."
  #puts "This is the global quit command."
  BufferManager.kill_all_buffers_safely
  if log_io = @@log_io
    Logger.remove_sink(log_io)
    log_io.close
  end
  Ncurses.end
  exit 0
end

def quit_ask
  if BufferManager.ask_yes_or_no "Really quit?"
    quit_now
  end
end

def roll_buffers
  BufferManager.roll_buffers
end

def roll_buffers_backwards
  BufferManager.roll_buffers_backwards
end

def kill_buffer
  BufferManager.kill_buffer_safely(BufferManager.focus_buf)
end

def main
  init_managers

  start_cursing

  mode = InboxMode.new
  buf = BufferManager.spawn("Inbox Mode", mode, Opts.new({:width => 80, :height => 25}))
  BufferManager.raise_to_front(buf)

  global_keymap = Keymap.new do |k|
    k.add :roll_buffers, "Switch to next buffer", 'b'
    k.add :roll_buffers_backwards, "Switch to previous buffer", 'B'
    k.add :quit_ask, "Quit Sup, but ask first", 'q'
    k.add :quit_now, "Quit Sup immediately", 'Q'
    k.add :kill_buffer, "Kill the current buffer", 'x'
  end

  # Interactive loop.
  begin
    event_loop(global_keymap) {|ch| BufferManager.flash "No action for #{ch}"}
  rescue ex
    Ncurses.end
    puts "Oh crap!  An exception occurred!"
    puts ex.inspect_with_backtrace
    exit 1
  end

end

main

{% end %} # flag MAIN

end	# Redwood
