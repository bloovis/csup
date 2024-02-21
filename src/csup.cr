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
require "./logger"
require "./modes/inbox_mode"
require "./modes/buffer_list_mode"
require "./modes/search_results_mode"
require "./modes/search_list_mode"
require "./modes/help_mode"
require "./modes/contact_list_mode"
require "./draft"

module Redwood
  BASE_DIR = File.join(ENV["HOME"], ".csup")

  extend self

  @@log_io : IO?
  @@poll_mode : PollMode?
  @@global_keymap : Keymap?

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
    sentm = SentManager.new(Config.str(:sent_folder) || "sent")
    dm = DraftManager.new(Config.str(:draft_folder) || "draft")

    log_io = File.open(File.join(basedir, "log"), "a")
    if log_io
      logm = Logger.new
      Logger.add_sink(log_io)
      @@log_io = log_io
    end
  end

  def event_loop(keymap, &b)
    # The initial draw_screen won't draw the buffer status, because
    # the status is set as a result of calling draw_screen.  Hence,
    # we need to call it again at the beginning of the event loop.
    BufferManager.draw_screen

    # Get the poll interval in seconds, and convert it to milliseconds.
    poll_interval = Config.int(:poll_interval) * 1000
    while true
      BufferManager.draw_screen
      # Get a key with five minute timeout.  If the timeout occurs,
      # ch will equal "ERR" and the poll command will run.
      ch = Ncurses.getkey(poll_interval)
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

  # Accessor used by EditMessageMode to redirect EMail::Client log messages.
  def log_io
    @@log_io
  end

  # Dummy poll mode that exists only for the ability to call UpdateManager.relay
  # after polling.
  class PollMode < Mode
    def initialize
      @notmuch_lastmod = Notmuch.lastmod
    end

    def poll
      # Run the before-poll hook, and display a flash showing whether it
      # succeeded, along with whatever string it printed.
      result = ""
      success = HookManager.run("before-poll") do |pipe|
	pipe.receive do |f|
	  result = f.gets_to_end
	end
      end
      #STDERR.puts "before-poll: success #{success}, result #{result}"
      if success
	BufferManager.flash result
      else
	if result.size > 0
	  BufferManager.flash "before-poll hook failed: #{result}"
	else
	  BufferManager.flash "before-pool hook failed"
	end
      end

      # Ask notmuch to poll for new messages.  Then create
      # a notmuch search term that will result in a list
      # of threads that are new/updated since the last poll.
      # Relay the search term to any waiting thread index modes.
      Notmuch.poll
      nowmod = Notmuch.lastmod
      #STDERR.puts "nowmod #{nowmod}, lastmod #{@notmuch_lastmod}"
      return if nowmod == @notmuch_lastmod
      search_terms = "lastmod:#{@notmuch_lastmod}..#{nowmod}"
      @notmuch_lastmod = nowmod
      UpdateManager.relay self, :poll, search_terms
    end
  end

  def poll
   unless poll_mode = @@poll_mode
     poll_mode = PollMode.new
     @@poll_mode = poll_mode
   end
   poll_mode.poll
  end

{% if flag?(:MAIN) %}

# Functions required by main.  We have to use `extend self` to overcome
# namespace problems with the `actions` macro.

extend self

def finish
  LabelManager.save if Redwood::LabelManager.instantiated?
  ContactManager.save if Redwood::ContactManager.instantiated?
  SearchManager.save if Redwood::SearchManager.instantiated?
  Logger.remove_sink @@log_io

  #managers.each { |x| x.deinstantiate! if x.instantiated? }
  # Need to add DraftManager, PollManager, CryptoManager, LayoutManager
  # if they ever get implemented.
  {% for name in [HookManager, ContactManager, LabelManager, AccountManager,
		  UpdateManager, UndoManager,
		  SearchManager, SentManager] %}
    {{name.id}}.deinstantiate! if {{name.id}}.instantiated?
  {% end %}

  if log_io = @@log_io
    log_io.close
    @@log_io = nil
  end
end

# Commands.  Every command must be listed in the actions macro below.
actions quit_now, quit_ask, kill_buffer, roll_buffers, roll_buffers_backwards,
        list_buffers, list_contacts, redraw, search, poll, compose, help

def quit_now
  #BufferManager.say "This is the global quit command."
  #puts "This is the global quit command."
  return unless BufferManager.kill_all_buffers_safely
  finish
  Ncurses.end
  Logger.remove_all_sinks!
  if log_io = @@log_io
    Logger.remove_sink(log_io)
    log_io.close
  end
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

def list_buffers
  BufferManager.spawn_unless_exists("buffer list", Opts.new({:system => true})) { BufferListMode.new }
end

def list_contacts
  b, new = BufferManager.spawn_unless_exists("Contact List") { ContactListMode.new }
  #mode.load_in_background if new
end

def redraw
  BufferManager.completely_redraw_screen
end

def search
  # FIXME: This is much simpler than in Sup: no completions, no SearchListMode.
  #completions = LabelManager.all_labels.map { |l| "label:#{LabelManager.string_for l}" }
  #completions = completions.each { |l| l.fix_encoding! }
  #completions += Index::COMPL_PREFIXES
  #query = BufferManager.ask_many_with_completions :search, "Search all messages (enter for saved searches): ", completions
  query = BufferManager.ask :search, "Search all messages (enter for saved searches): "
  #STDERR.puts "about to spawn search results mode with '#{query}'"
  unless query.nil?
    if query.empty?
      BufferManager.spawn_unless_exists("Saved searches") { SearchListMode.new }
    else
      SearchResultsMode.spawn_from_query query
    end
  end
end

def compose
  ComposeMode.spawn_nicely
end

def help
  STDERR.puts "help command"
  return unless global_keymap = @@global_keymap
  return unless focus_buf = BufferManager.focus_buf
  return unless curmode = focus_buf.mode
  BufferManager.spawn_unless_exists("<help for #{curmode.name}>") do
    HelpMode.new(curmode, global_keymap)
  end
end

# Main program
def main
  init_managers

  start_cursing

  @@poll_mode = PollMode.new
  lmode = Redwood::LogMode.new "system log"
  lmode.on_kill { Logger.clear! }
  Logger.add_sink lmode
  Logger.force_message "Welcome to Csup! Log level is set to #{Logger.level}."
  if (level = Logger::LEVELS.index(Logger.level)) && level > 0
    Logger.force_message "For more verbose logging, restart with CSUP_LOG_LEVEL=" +
			 "#{Logger::LEVELS[level-1]}."
  end

  mode = InboxMode.new
  buf = BufferManager.spawn("Inbox Mode", mode, Opts.new({:width => 80, :height => 25}))
  BufferManager.raise_to_front(buf)
  poll

  global_keymap = Keymap.new do |k|
    k.add :quit_ask, "Quit Sup, but ask first", 'q'
    k.add :quit_now, "Quit Sup immediately", 'Q'
    k.add :help, "Show help", '?'
    k.add :roll_buffers, "Switch to next buffer", 'b'
    k.add :roll_buffers_backwards, "Switch to previous buffer", 'B'
    k.add :kill_buffer, "Kill the current buffer", 'x'
    k.add :list_buffers, "List all buffers", ';'
    k.add :list_contacts, "List contacts", 'C'
    k.add :redraw, "Redraw screen", "C-l"
    k.add :search, "Search all messages", '\\', 'F'
    k.add :poll, "Poll for new messages", 'P', "ERR"
    k.add :compose, "Compose new message", 'm', 'c'
  end
  @@global_keymap = global_keymap

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
