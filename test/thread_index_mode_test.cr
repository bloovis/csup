require "../src/modes/thread_index_mode.cr"

module Redwood

extend self
actions(quit)

def quit
  BufferManager.say "This is the global quit command."
  #puts "This is the global quit command."
  Ncurses.end
  exit 0
end

def run_gui(threadlist)
  init_managers

  mode = ThreadIndexMode.new(threadlist)

  start_cursing

  buf = BufferManager.spawn("Thread Index Mode", mode, Opts.new({:width => 80, :height => 25}))
  BufferManager.raise_to_front(buf)

  global_keymap = Keymap.new do |k|
    k.add(:quit, "Quit", "q", "C-q")
    k.add(:help, "Help", "h")
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
  puts "About to call ThreadList.new, query #{query}"
  threadlist = Redwood::ThreadList.new(query, offset: 0, limit: 10)
  puts "About to call run_gui"
  run_gui(threadlist)
end

main

end	# Redwood
