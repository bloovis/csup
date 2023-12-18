require "../src/logger.cr"

module Redwood

l = Logger.new("debug")
Logger.debug("This is a test of debug level")
puts "Adding sink STDOUT"
Logger.add_sink(STDOUT)
debug "This is another test of debug level using global function after adding sink STDOUT"
Logger.set_level("info")
debug "This is a debug message with level set to info -- should not appear!"
warn "This is a warn message with level set to info -- should appear"
info "This is an info message with level set to info - should appear"
error "This is an error message with level set to info - should appear"
end
