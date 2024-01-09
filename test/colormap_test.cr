require "../src/csup"

module Redwood

#Colormap.reset # this causes a "Colormap not instantiated!" exception
cm = Colormap.new(File.join(BASE_DIR, "colors.yaml"))
Colormap.reset
Colormap.populate_colormap
x = Colormap.color_for(:label_color)
puts "label_color = #{x}"
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

end
