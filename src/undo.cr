require "./singleton"

module Redwood

## Implements a single undo list for the Sup instance
##
## The basic idea is to keep a list of lambdas to undo
## things. When an action is called (such as 'archive'),
## a lambda is registered with UndoManager that will
## undo the archival action

class UndoManager
  singleton_class(UndoManager)

  alias UndoEntry = NamedTuple(desc: String, action: Proc(Nil))

  @@actionlist = [] of UndoEntry

  def initialize
    singleton_pre_init
    # @@actionlist = [] of UndoEntry
    singleton_post_init
  end

  def register(desc : String, action : Proc(Nil))
    @@actionlist.push({desc: desc, action: action})
  end
  singleton_method(UndoManager, register, desc, action)

  def undo
    unless @@actionlist.empty?
      actionset = @@actionlist.pop
      action = actionset[:action]
      action.call
      puts "undid #{actionset[:desc]}"
      # BufferManager.flash "undid #{actionset[:desc]}"
    else
      # BufferManager.flash "nothing more to undo!"
    end
  end
  singleton_method(UndoManager, undo)

  def clear
    @@actionlist = [] of UndoEntry
  end
  singleton_method(UndoManager, clear)
end	# UndoManager

end	# Redwood
