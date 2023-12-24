require "../src/hook"

module Redwood

hm = HookManager.new("./hooks")
HookManager.run("htmltotext") do |pipe|
  pipe.send do |f|
    f.puts("<html><body><p>First paragraph.</p><p>Second paragraph.</p></body></html>")
  end
  pipe.receive do |f|
    result = f.gets_to_end
    print "result: #{result}"
  end
end

end
