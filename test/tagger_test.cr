require "../src/mode"
require "../src/keymap"
require "../src/tagger"

module Redwood

class ListMode < Mode

#  @tags : Tagger

  def initialize
    @tags = Tagger.new
    @tags.setmode(self)
    puts "Initializing ListMode"
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
  end

end

lm = ListMode.new
lm.test

end	# module Redwood
