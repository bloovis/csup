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

class UndoManager
  singleton_class

  alias Action = Proc(Nil)
  alias UndoEntry = NamedTuple(desc: String, actions: Array(Action))

  @actionlist = [] of UndoEntry

  def initialize
    singleton_pre_init
    @actionlist = [] of UndoEntry
    singleton_post_init
  end

  # Because Crystal doesn't have way to test for the existence of a block,
  # like Ruby's block_given?, we provide two entry points for register: one that
  # takes a block and one that doesn't.
  def do_register(desc : String, block_given? = true, *actions, &block : Action)
    a = Array(Action).new
    actions.map {|action| a << action}
    if block_given?
      a << block
    end
    @actionlist.push({desc: desc, actions: a})
  end

  def self.register(desc, *actions, &b)
    instance.do_register(desc, true, *actions, &b)
  end

  def self.register(desc, *actions)
    instance.do_register(desc, false, *actions) {}
  end

  def undo
    unless @actionlist.empty?
      actionset = @actionlist.pop
      actions = actionset[:actions]
      actions.each do |action|
	action.call
      end
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
    @actionlist = [] of UndoEntry
  end
  singleton_method clear
end	# UndoManager

end	# Redwood
