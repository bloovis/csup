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

def run_gui(query : String)
  init_managers

  start_cursing

  mode = ThreadIndexMode.new(query)
  buf = BufferManager.spawn("Thread Index Mode", mode, Opts.new({:width => 80, :height => 25}))
  BufferManager.raise_to_front(buf)

  global_keymap = Keymap.new do |k|
    k.add(:quit, "Quit", "q", "C-q")
    k.add(:kill_buffer, "Kill the current buffer", "x")
  end

  # Interactive loop.
  event_loop(global_keymap) {|ch| BufferManager.flash "No action for #{ch}"}
end

def main
  if ARGV.size != 1
    puts "Must provide a notmuch search query."
    exit 1
  end
  query = ARGV[0]
  run_gui(query)
end

main

end	# Redwood
