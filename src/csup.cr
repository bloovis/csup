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
    while true
      ch = BufferManager.ask_getch("Command: ")
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
