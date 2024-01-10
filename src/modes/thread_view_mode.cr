require "./line_cursor_mode"

module Redwood

class ThreadViewMode < LineCursorMode
  mode_class help

  @text = Array(String).new
  property display_content = false

  register_keymap do |k|
    k.add(:help, "help", "h")
    k.add(:select_item, "Select this item", "C-m")
  end

  def lines
    @text.size
  end

  def [](n) : Text
    @text[n]
  end

  def initialize(thread : MsgThread)
    super()
    display_thread(thread)
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

  def select_item
    BufferManager.flash "Select item at #{curpos}"
  end
end

end	# Redwood
