require "../src/message.cr"

def main
  print_content = false
  query = ""
  ARGV.each do |arg|
    if arg == "-c"
      print_content = true
    else
      query = arg
    end
  end
  threadlist = Redwood::ThreadList.new(query, offset: 0, limit: 10)
  threadlist.print(print_content: print_content)
end

main
