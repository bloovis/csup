require "./scroll_mode"

module Redwood

class TextMode < ScrollMode
  mode_class save_to_disk, pipe

  @text = Array(String).new
  @filename = ""

  register_keymap do |k|
    k.add :save_to_disk, "Save to disk", 's'
    k.add :pipe, "Pipe to process", '|'
  end

  def initialize(text="", @filename = "")
    @text = text.lines
    #STDERR.puts "TextMode: text = #{@text.join("|")}"
    if buffer
      ensure_mode_validity
      buffer.mark_dirty
    end
    buffer.mark_dirty if buffer
    super()
  end

  def save_to_disk(*args)
    fn = BufferManager.ask_for_filename :filename, "Save to file: ", @filename
    return unless fn && fn != ""
    save_to_file(fn) do |f|
      @text.each {|l| f.puts l }
    end
  end

  def pipe(*args)
    command = BufferManager.ask(:shell, "pipe command: ")
    return if command.nil? || command.empty?

    output, success = pipe_to_process(command) do |stream|
      @text.each { |l| stream.puts l }
    end

    unless success
      BufferManager.flash "Invalid command: '#{command}' is not an executable"
      return
    end

    if output
      BufferManager.spawn "Output of '#{command}'", TextMode.new(output)
    else
      BufferManager.flash "'#{command}' done!"
    end
  end

  def <<(line : String)
    @text << line.rstrip
    if buffer
      ensure_mode_validity
      buffer.mark_dirty
    end
  end

  def text=(t)
    @text = t.lines
  end

  def lines
    @text.size
  end

  def [](i)
    @text[i]
  end

end

end
