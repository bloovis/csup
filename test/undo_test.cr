require "../src/undo"

module Redwood

class UndoTest
  property x = 42

  def handle_undo_1
    puts "Handling undo #1 for class #{self.class.name}"
  end

  def handle_undo_2
    puts "Handling undo #2 for class #{self.class.name}"
  end

  def undo_proc
    return -> do
      puts "undo in a proc returned by a method, x = #{x}"
    end
  end

  def doit
    # Try it with just blocks.
    puts "Testing with just blocks"
    UndoManager.register("Block undo #1") {handle_undo_1}
    UndoManager.register("Block undo #2") {handle_undo_2}
    UndoManager.undo
    UndoManager.undo
    UndoManager.undo	# should result in error message

    # Try it with single Procs
    puts "Testing with single Procs"
    UndoManager.register("Proc undo #1", -> handle_undo_1)
    UndoManager.register("Proc undo #2", -> handle_undo_2)
    UndoManager.undo
    UndoManager.undo
    UndoManager.undo	# should result in error message

    # Try it with multiple Procs
    puts "Testing with multiple Procs"
    UndoManager.register("Multiple Procs undo", -> handle_undo_1, -> handle_undo_2)
    UndoManager.undo
    UndoManager.undo	# should result in error message

    # Try it with Proc and a block
    puts "Testing with Proc and block"
    UndoManager.register("Proc and block undo #1", -> handle_undo_1) do
      puts "Proc and block undo #1"
    end
    UndoManager.register("Proc and Block undo #2", -> handle_undo_2) do
      puts "Proc and block undo #2"
    end
    UndoManager.undo
    UndoManager.undo	# should result in error message

    # Try it with a Proc returned by a method
    puts "Testing with Proc returned by a method"
    UndoManager.register("Proc returned by method", undo_proc);
    # Changing x now should not change the context of the undo_proc.
    x = 666
    UndoManager.undo
    UndoManager.undo	# should result in error message

  end
end

um = UndoManager.new
u = UndoTest.new
u.doit

end	# Redwood
