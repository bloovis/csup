require "./singleton"
require "./notmuch"

module Redwood

class SentManager
  singleton_class

  property folder = ""

  def initialize(folder : String)
    singleton_pre_init
    @folder = folder
    singleton_post_init
  end

  def self.write_sent_message(&block : IO -> _) : Bool
    stored = false
    ##::Thread.new do
      debug "store the sent message"
      stored = Notmuch.insert(instance.folder, &block)
    ##end #Thread.new
    stored
  end
  #def self.write_sent_message(&block) : Bool
  #  self.instance.do_write_sent_message(&block)
  #end

end # class

end # module
