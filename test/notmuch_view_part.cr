require "../src/notmuch"
require "../src/hook"
require "../src/csup"

module Redwood

init_managers
print "Enter message ID: "
msgid = (gets || "").strip
print "Enter part ID: "
partid = (gets || "0").strip.to_i
print "Enter mime type: "
mimetype = (gets || "").strip

success = Notmuch.view_part(msgid, partid, mimetype)
puts "Success = #{success}"

end	# Redwood
