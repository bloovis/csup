require "../src/modes/inbox_mode.cr"

module Redwood

extend self
actions(quit, kill_buffer)

def quit
  BufferManager.say "This is the global quit command."
  #puts "This is the global quit command."
  Ncurses.end
  exit 0
end

def kill_buffer
  BufferManager.kill_buffer_safely(BufferManager.focus_buf)
end

def run_gui
  init_managers

  start_cursing

  mode = InboxMode.new
  buf = BufferManager.spawn("Inbox Mode", mode, Opts.new({:width => 80, :height => 25}))
  BufferManager.raise_to_front(buf)

  global_keymap = Keymap.new do |k|
    k.add(:quit, "Quit", "q", "C-q")
    k.add(:kill_buffer, "Kill the current buffer", "x")
  end

  # Interactive loop.
  event_loop(global_keymap) {|ch| BufferManager.flash "No action for #{ch}"}
end

def main
  run_gui
end

main

end	# Redwood
