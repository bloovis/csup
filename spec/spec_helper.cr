require "spec"
require "../src/contact.cr"

def create_contacts(filename)
  s = <<-EOS
self: Mark Alexander <marka@pobox.com>
potus: Robert L. Peters <potus@whitehouse.gov>
putin: Vladimir Putin <vlad@kremlin.ru>
EOS
  File.write(filename, s)
end
