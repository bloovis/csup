require "../src/message"
require "../src/config"
require "../src/modes/line_cursor_mode"

module Redwood

class MessageMode < LineCursorMode
  mode_class help

  @text = Array(String).new
  property display_content = false

  register_keymap do |k|
    k.add(:help, "help", "h")
  end

  def lines
    @text.size
  end

  def [](n) : Text
    @text[n]
  end

  def initialize(threadlist : ThreadList, @display_content)
    super()
    threadlist.threads.each_with_index do |thread, i|
      @text << "----"
      @text << "Thread #{i}:"
      display_thread(thread)
    end
  end

  def display_thread(thread : MsgThread)
    m = thread.msg
    if m
      display_message(m)
    end
  end

  def display_message(msg : Message, level = 0)
    prefix = "  " * level
    @text << "#{prefix}Message:"
    @text << "#{prefix}  id: #{msg.id}"
    @text << "#{prefix}  filename: #{msg.filename}"
    parent = msg.parent
    if parent
      @text << "#{prefix}  parent id: #{parent.id}"
    end

    @text << "#{prefix}  timestamp: #{msg.timestamp} (#{Time.unix(msg.timestamp)})"
    @text << "#{prefix}  tags: #{msg.tags.join(",")}"
    @text << "#{prefix}  date_relative: #{msg.date_relative}"

    @text << "#{prefix}  headers:"
    msg.headers.each do |k,v|
      @text << "#{prefix}    #{k} = #{v}"
    end

    msg.content.each do |id, c|
      colon = (@display_content ? ":" : "")
      @text << "#{prefix}  Content ID #{c.id}, content type #{c.content_type}, filename '#{c.filename}'#{colon}\n"
      if c.content == ""
	@text << "#{prefix}  Content missing!"
      elsif @display_content
        c.content.lines.each {|l| @text << l}
      end
    end

    if msg.children.size > 0
      @text << "#{prefix}  Children:"
      msg.children.each do |child|
	display_message(child, level + 2)
      end
    end

  end

  def help
    BufferManager.flash "This is the help command."
    #puts "This is the help command."
  end
end

extend self
actions(quit)

def quit
  BufferManager.say "This is the global quit command."
  #puts "This is the global quit command."
  Ncurses.end
  exit 0
end


def run_gui(threadlist : ThreadList, display_content = false)
  cm = Config.new
  bm = BufferManager.new
  colormap = Colormap.new
  Colormap.reset
  Colormap.populate_colormap
  mode = MessageMode.new(threadlist, display_content: display_content)
  puts "Ancestors of MessageMode:"
  puts mode.ancestors

  start_cursing
  buf = bm.spawn("Message Test Mode", mode, Opts.new({:width => 80, :height => 25}))
  bm.raise_to_front(buf)

  global_keymap = Keymap.new do |k|
    k.add(:quit, "Quit", "q", "C-q")
    k.add(:help, "Help", "h")
  end

  bm.draw_screen Opts.new({:refresh => true})
  # Interactive loop.
  while true
    #ch = bm.ask_getch("Command: ")
    ch = Ncurses.getkey
    bm.erase_flash
    bm.draw_screen
    #print "Command: "
    #ch = gets || ""
    unless bm.handle_input(ch)
      # Either of the following two calls should work.
      #action = BufferManager.resolve_input_with_keymap(ch, global_keymap)
      action = bm.resolve_input_with_keymap(ch, global_keymap)
      if action
	send action
      else
	BufferManager.flash "No action for #{ch}.  Maybe you should try again?"
	#puts "No action for #{ch}"
      end
    end
    bm.draw_screen
  end
end

def main
  print_content = false
  query = ""
  gui = false
  ARGV.each do |arg|
    if arg == "-c"
      print_content = true
    elsif arg == "-g"
      gui = true
    else
      query = arg
      puts "Setting query to #{query}"
    end
  end
  puts "About to call ThreadList.new, query #{query}"
  threadlist = Redwood::ThreadList.new(query, offset: 0, limit: 10)
  if gui
    puts "About to call run_gui, display_content #{print_content}"
    run_gui(threadlist, display_content: print_content)
  else
    threadlist.print(print_content: print_content)
  end
end

main

end	# Redwood