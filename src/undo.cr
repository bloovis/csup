require "./singleton"
require "./supcurses"
require "./buffer"
require "./keymap"

module Redwood

## Implements a single undo list for the Sup instance
##
## The basic idea is to keep a list of lambdas to undo
## things. When an action is called (such as 'archive'),
## a lambda is registered with UndoManager that will
## undo the archival action
#
# The Crystal implementation differs from the one in Sup
# in that the register method does not take lambdas as
# parameters, but instead expects a block that takes no parameters.

class UndoManager
  singleton_class

  alias UndoEntry = NamedTuple(desc: String, action: Proc(Nil))

  @@actionlist = [] of UndoEntry

  def initialize
    singleton_pre_init
    # @@actionlist = [] of UndoEntry
    singleton_post_init
  end

  def register(desc : String, &action)
    @@actionlist.push({desc: desc, action: action})
  end
  def self.register(desc, &b)
    instance.register(desc, &b)
  end

  def undo
    unless @@actionlist.empty?
      actionset = @@actionlist.pop
      action = actionset[:action]
      action.call
      if Redwood.cursing
        BufferManager.flash "undid #{actionset[:desc]}"
      else
	puts "undid #{actionset[:desc]}"
      end
    else
      if Redwood.cursing
	BufferManager.flash "nothing more to undo!"
      else
	puts "nothing more to undo!"
      end
    end
  end
  singleton_method undo, b

  def clear
    @@actionlist = [] of UndoEntry
  end
  singleton_method clear
end	# UndoManager

end	# Redwood
