require "./line_cursor_mode"

module Redwood

class ThreadViewMode < LineCursorMode
  mode_class help

  @text = Array(String).new
  @display_content = false

  register_keymap do |k|
    k.add(:help, "help", "h")
  end

  def lines
    @text.size
  end

  def [](n) : Text
    @text[n]
  end

  def initialize(thread : MsgThread, @display_content = false)
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
    t = msg.thread
    if t
      @text << "#{prefix}  thread object id: #{t.object_id}"
    else
      @text << "#{prefix}  No containing thread!"
    end
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

    msg.parts.each do |p|
      colon = (@display_content ? ":" : "")
      @text << "#{prefix}  Part ID #{p.id}, content type #{p.content_type}, filename '#{p.filename}'#{colon}\n"
      if p.content == ""
	@text << "#{prefix}  Content missing!"
      elsif @display_content
        p.content.lines.each {|l| @text << prefix + "    " + l}
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
