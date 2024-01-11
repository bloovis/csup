require "./keymap"
require "./config"
require "./buffer"
require "./colormap"
require "./search"
require "./undo"
require "./update"
require "./hook"
require "./account"

module Redwood
  BASE_DIR = File.join(ENV["HOME"], ".csup")

  extend self

  def init_managers
    basedir = BASE_DIR

    cm = Config.new(File.join(basedir, "config.yaml"))
    bm = BufferManager.new
    colormap = Colormap.new(File.join(basedir, "colors.yaml"))
    Colormap.reset
    Colormap.populate_colormap
    sm = SearchManager.new(File.join(basedir, "searches.txt"))
    unm = UndoManager.new
    upm = UpdateManager.new
    hm = HookManager.new(File.join(basedir, "hooks"))
    am = AccountManager.new(Config.accounts)
  end

  def event_loop(keymap, &b)
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

end	# Redwood
