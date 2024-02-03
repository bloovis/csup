require "../src/notmuch"

module Redwood

print "Enter message ID: "
msgid = (gets || "").strip
print "Enter part ID: "
partid = (gets || "0").strip.to_i
print "Enter output filename: "
filename = (gets || "").strip

f = File.open(filename, "w")
success = Notmuch.write_part(msgid, partid) {|part| IO.copy(part, f)}
f.close
puts "Success = #{success}"

end	# Redwood
