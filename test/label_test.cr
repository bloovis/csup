require "../src/csup"

module Redwood

init_managers

puts "All labels before addition:"
LabelManager.all_labels.each {|l| puts "Label: #{l} (#{LabelManager.string_for(l)})"}

puts "All user-defined labels before addition:"
LabelManager.user_defined_labels.each {|l| puts "User label: #{l} (#{LabelManager.string_for(l)})"}

puts "Adding :blorch"
LabelManager << :blorch
if LabelManager.new_label?(:blorch)
  puts ":blorch is a new label"
else
  puts "blorch is not a new label"
end
LabelManager.save

end
