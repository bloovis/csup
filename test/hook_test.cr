require "../src/hook"
require "json"

module Redwood

hm = HookManager.new("./hooks")

# Run a test of a hook that takes plain text for input and outputs plain text.
success = HookManager.run("htmltotext") do |pipe|
  pipe.send do |f|
    f.puts("<html><body><p>First paragraph.</p><p>Second paragraph.</p></body></html>")
  end
  pipe.receive do |f|
    result = f.gets_to_end
    print "result: #{result}"
  end
end

puts "htmltotext hook failed" unless success

# Run a test of a hook that takes a JSON request and replies with JSON.
success = HookManager.run("pluralize") do |pipe|
  noun = "tree"
  pipe.send do |f|
    h = {"noun" => noun}
    j = h.to_json
    puts "Request: #{j}"
    f.puts(j)
  end
  pipe.receive do |f|
    s = f.gets_to_end
    puts "Reply: #{s}"
    reply = JSON.parse(s)
    plural = reply["plural"].as_s
    puts "Plural of #{noun} is #{plural}"
  end
end

puts "pluralize hook failed" unless success

end
