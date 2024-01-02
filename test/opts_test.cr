require "../src/opts"

module Redwood

opts = Opts.new({:hidden => false, :cols => 80})
opts[:highlight] = false
opts[:color] = :text_color
opts[:filename] = "filename.cr"
opts[:hidden_tags] = ["spam", "deleted"]
opts[:skip_rows] = 2

puts "opts = " + opts.inspect

puts "hidden = #{opts.bool(:hidden)}"
puts "cols = #{opts.int(:cols)}"
puts "highlight = #{opts.bool(:highlight)}"
puts "color = #{opts.sym(:color)}"
puts "filename = #{opts.str(:filename)}"
puts "hidden tags = #{opts.strarray(:hidden_tags)}"
puts "skip_rows = #{opts.int(:skip_rows)}"
if opts.member?(:junk)
  puts ":junk is in opts, which should not be true!"
else
  puts ":junk is is not opts, but let's try to retrieve it anyway"
  junk = opts.str(:junk) || "junk not in opts!"
end

puts "junk = #{junk}"

opts.merge({:junk => :none})
puts "junk = #{opts.sym(:junk)}"

junk = opts.delete_sym(:junk)
puts "junk after deletion = #{junk}"
if opts.member?(:junk)
  puts "junk is still a member after deleting, which should not be true!"
else
  puts "junk is not a member after deletion, good!"
end

end
