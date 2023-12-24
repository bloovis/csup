require 'json'

# Read a JSON string from stdin, return it as a hash.

def read_json
  JSON.parse(STDIN.read)
end

# Convert a hash to JSON and write it to stdout.

def write_json(h)
  puts JSON.generate(h)
end
