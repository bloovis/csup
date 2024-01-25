require "../src/logger"
require "../src/modes/log_mode"

module Redwood

l = Logger.new("debug")
Logger.debug("This is a test of debug level")
puts "Adding sink STDOUT"
Logger.add_sink(STDOUT)
debug "This is another test of debug level using global function after adding sink STDOUT"
Logger.level = "info"
debug "This is a debug message with level set to info -- should not appear!"
warn "This is a warn message with level set to info -- should appear"
info "This is an info message with level set to info - should appear"
error "This is an error message with level set to info - should appear"
puts "Removing all sinks"
Logger.remove_all_sinks!
info "Here is a new info message that will appear after sink STDOUT is added"
info "Here is another info message like the one just previous"
puts "Adding sink STDOUT"
Logger.add_sink(STDOUT)
puts "Removing all sinks"
Logger.remove_all_sinks!
info "This message will get lost due to clear!"
puts "Clearing buffer"
Logger.clear!
info "This message will be seen after adding sink STDOUT"
puts "adding sink STDOUT"
Logger.add_sink(STDOUT)
end
