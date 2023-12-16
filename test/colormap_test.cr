require "../src/colormap"
require "../lib/ncurses/src/ncurses"
require "../src/supcurses"

cm = Colormap.new {}
cm.populate_colormap
x = cm.color_for("text_color")
puts "text_color = #{x}"
x = cm.color_for(:tagged_color)
puts "tagged_color = #{x}"
