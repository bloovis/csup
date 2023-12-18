require "../src/colormap"
require "../lib/ncurses/src/ncurses"
require "../src/supcurses"

cm = Colormap.new
Colormap.reset
Colormap.populate_colormap
x = Colormap.color_for("text_color")
puts "text_color = #{x}"
x = Colormap.color_for(:tagged_color)
puts "tagged_color = #{x}"
x = Colormap.color_for(:tagged_color)
puts "tagged_color = #{x}"
if Colormap.sym_is_defined(:index_starred_color)
  x = Colormap.color_for(:index_starred_color)
  puts ":index_starred is #{x}"
else
  puts ":index_starred is not defined"
end
