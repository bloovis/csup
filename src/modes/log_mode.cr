require "./text_mode"

module Redwood

## a variant of text mode that allows the user to automatically follow text,
## and respawns when << is called if necessary.

class LogMode < TextMode
  mode_class toggle_follow

  register_keymap do |k|
    k.add :toggle_follow, "Toggle follow mode", 'f'
  end

  ## if buffer_name is supplied, this mode will spawn a buffer
  ## upon receiving the << message. otherwise, it will act like
  ## a regular buffer.
  def initialize(autospawn_buffer_name : String? = nil)
    @follow = true
    @autospawn_buffer_name = autospawn_buffer_name
    @on_kill = [] of Proc(Nil)
    super()
  end

  ## register callbacks for when the buffer is killed
  def on_kill(&b); @on_kill << b end

  def toggle_follow(*args)
    @follow = !@follow
    if @follow
      jump_to_line(lines - buffer.content_height + 1) # leave an empty line at bottom
    end
    buffer.mark_dirty
  end

  def <<(s : String)
    if buffer.nil? && (bname = @autospawn_buffer_name)
      BufferManager.spawn bname, self, Opts.new({:hidden => true, :system => true})
    end

    s.split("\n").each { |l| super(l + "\n") } # insane. different << semantics.

    if @follow
      follow_top = lines - buffer.content_height + 1
      jump_to_line follow_top if topline < follow_top
    end
  end

  def status
    super + " (follow: #@follow)"
  end

  def cleanup
    @on_kill.each { |cb| cb.call }
    self.text = ""
    super
  end
end

end
