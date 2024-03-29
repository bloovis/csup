require "../src/csup"
require "json"

module Redwood

init_managers

# Run a test of a hook that takes HTML for input and outputs plain text.
success = HookManager.run("htmltotext") do |pipe|
  pipe.transmit do |f|
    f.puts("<html><body><p>First paragraph.</p><p>Second paragraph.</p></body></html>")
  end
  pipe.receive do |f|
    result = f.gets_to_end
    print "result of htmltotext hook:\n---\n#{result}\n---\n"
  end
end

puts "htmltotext hook failed" unless success

# Run a test of a hook that reads mime-encoded input and outputs plain text.
# The first line of the input is the content-type.
success = HookManager.run("mime-decode") do |pipe|
  pipe.transmit do |f|
    f.puts("text/html")
    f.puts("<html><body><p>First paragraph.</p><p>Second paragraph.</p></body></html>")
  end
  pipe.receive do |f|
    result = f.gets_to_end
    print "result of mime-decode hook:\n---\n#{result}\n---\n"
  end
end

puts "mime-decode hook failed" unless success

# Run a test of a hook that takes a JSON request and replies with JSON.
success = HookManager.run("pluralize") do |pipe|
  noun = "tree"
  pipe.transmit do |f|
    h = {"noun" => noun}
    j = h.to_json
    puts "Request: #{j}"
    f.puts(j)
  end
  pipe.receive do |f|
    s = f.gets_to_end
    puts "Reply: '#{s}'"
    reply = JSON.parse(s)
    plural = reply["plural"].as_s
    puts "Plural of #{noun} is #{plural}"
  end
end

puts "pluralize hook failed" unless success

# Run the signature hook, which doesn't take any input, only outputs some text.
success = HookManager.run("signature") do |pipe|
  pipe.receive do |f|
    result = f.gets_to_end
    print "result of signature hook:\n---\n#{result}\n---\n"
  end
end

puts "signature hook failed" unless success

end
