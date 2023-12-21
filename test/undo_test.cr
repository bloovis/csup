require "../src/undo"

module Redwood

class UndoTest
  def handle_undo_1
    puts "Handling undo #1"
  end

  def handle_undo_2
    puts "Handling undo #2"
  end

  def doit
    UndoManager.register("Stupid undo #1", -> handle_undo_1)
    UndoManager.register("Stupid undo #2", -> handle_undo_2)
    UndoManager.undo
    UndoManager.undo
  end
end

um = UndoManager.new
u = UndoTest.new
u.doit

end	# Redwood
