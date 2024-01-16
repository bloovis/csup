require "../src/notmuch"

module Redwood

print "Enter message ID: "
msgid = (gets || "").strip
print "Enter part ID: "
partid = (gets || "0").strip.to_i
print "Enter output filename: "
filename = (gets || "").strip

success = Notmuch.save_part(msgid, partid, filename)
puts "Success = #{success}"

end	# Redwood
