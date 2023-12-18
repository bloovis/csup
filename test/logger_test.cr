require "../src/logger.cr"

module Redwood

l = Logger.new("debug")
Logger.add_sink(STDOUT)
Logger.debug("This is a test")

end
