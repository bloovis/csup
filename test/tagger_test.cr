require "../src/mode"
require "../src/keymap"
require "../src/tagger"
require "../src/message"

module Redwood

class ListMode < Mode
  mode_class apply_to_tagged, archive, quit, multi_archive

  @cursor_message : Message?

  register_keymap do |k|
    k.add(:quit, "Quit", "q")
    k.add(:archive, "Archive ", "a")
    k.add(:apply_to_tagged, "Apply next command to all tagged threads", "=")
  end

#  @tags : Tagger

  def initialize
    super
    @tags = Tagger(Message).new
    @tags.setmode(self)
    puts "Initializing ListMode"
  end

  def apply_to_tagged
    @tags.apply_to_tagged
  end

  def quit
    puts "This is the quit command."
    exit 0
  end

  def archive
    m = @cursor_message
    if m
      puts "In archive action, message id #{m.id}"
    else
      puts "In archive action, cursor_message is not set!"
    end
  end

  # Unlike in Sup, a "multi_{action}" method cannot take a parameter
  # containing the array of tagged objects.  Instead, it must fetch the array
  # by calling @tags.all
  def multi_archive
    ms  = @tags.all
    puts "In multi_archive action, message IDs:"
    ms.each {|m| puts "  #{m.id}"}
  end

  def print(s : String)
    puts s
    a = @tags.all
    a.each do |m|
      puts "Message #{m.id} is tagged"
    end
  end

  def test
    msg1 = Message.new("Message #1")
    msg2 = Message.new("Message #2")
    msg3 = Message.new("Message #3")
    msg4 = Message.new("Message #4")

    @tags.tag(msg1)
    @tags.tag(msg3)
    print("Expecting #1 and #3")

    @tags.untag(msg1)
    @tags.tag(msg4)
    print("Expecting #3 and #4")

    @tags.toggle_tag_for(msg2)
    print("Expecting #2, #3, and #4")

    @tags.toggle_tag_for(msg3)
    print("Expecting #2 and #4")

    @cursor_message = msg2
  end

end

puts "Cursing = #{Redwood.cursing}"

bm = BufferManager.new
lm = ListMode.new
puts "Ancestors: #{lm.ancestors}"
puts "respond_to?(:archive) = #{lm.respond_to?(:archive)}"
lm.test

while true
  ch = BufferManager.ask_getch("Command: ")
  #print "Command: "
  #ch = gets || ""
  unless lm.handle_input(ch)
    "No action for #{ch}"
  end
end

end	# module Redwood
