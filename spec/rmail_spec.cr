require "./spec_helper"
require "../src/rmail/address"
require "../src/rmail/utils"

describe RMail::Address do
  it "parses addresses in a group" do
    addr = "A Group:a@b.c,d@e.f;"
    parser = RMail::Address::Parser.new(addr)
    addrs = parser.parse
    addrs.size.should eq(2)

    a = addrs[0]
    a.address.should eq("a@b.c")
    a.local.should eq("a")
    a.name.should eq("")
    a.display_name.nil?.should eq(true)
    a.domain.should eq("b.c")
    a.format.rstrip(" ").should eq("a@b.c")
    a.comments.should eq([] of String)

    a = addrs[1]
    a.address.should eq("d@e.f")
    a.local.should eq("d")
    a.name.should eq("")
    a.display_name.nil?.should eq(true)
    a.domain.should eq("e.f")
    a.format.rstrip(" ").should eq("d@e.f")
    a.comments.should eq([] of String)
  end

  it "parses an address with a comment" do
    addr = "Mark Alexander <marka@pobox.com> (Some User)"
    parser = RMail::Address::Parser.new(addr)
    addrs = parser.parse
    addrs.size.should eq(1)

    a = addrs[0]
    a.address.should eq("marka@pobox.com")
    a.local.should eq("marka")
    a.name.should eq("Mark Alexander")
    a.display_name.should eq("Mark Alexander")
    a.domain.should eq("pobox.com")
    a.format.rstrip(" ").should eq("Mark Alexander <marka@pobox.com> (Some User)")
    a.comments.size.should eq(1)
    a.comments[0].should eq("Some User")
  end
end

describe RMail::QuotedPrintable do
  it "encodes and decodes a quotable-printable text" do
    data = <<-HTM
<html lang=\"ja\">\r
<head>\r
  <title>日本語タイトル</title>\r
</head>\r
<body>\r
  <h1>見出し</h1>\r
  <p>本文<p>\r
</body>\r
</html>\r
HTM
    encoded = RMail::QuotedPrintable.encode(data)
    expected = <<-HTM
<html lang=3D"ja">\r
<head>\r
  <title>=E6=97=A5=E6=9C=AC=E8=AA=9E=E3=82=BF=E3=82=A4=E3=83=88=E3=83=AB</t=\r
itle>\r
</head>\r
<body>\r
  <h1>=E8=A6=8B=E5=87=BA=E3=81=97</h1>\r
  <p>=E6=9C=AC=E6=96=87<p>\r
</body>\r
</html>=0D
HTM
    encoded.should eq(expected)

    decoded = RMail::QuotedPrintable.decode_string(encoded)
    decoded.should eq(data)
  end
end

describe RMail::Utils do
  it "unquotes a string" do
    s = "\"this is a string\""
    unquoted = RMail::Utils.unquote(s)
    unquoted.should eq("this is a string")

    s = "\"this is a string\\\""
    unquoted = RMail::Utils.unquote(s)
    unquoted.should eq(s)
  end

  it "decodes base64 data" do
    s = "U2VuZCByZWluZm9yY2VtZW50cw==\n"
    decoded = RMail::Utils.base64_decode(s)
    decoded.should eq("Send reinforcements")
  end

  it "decodes quoted-printable text" do
    encoded = <<-HTM
<html lang=3D"ja">\r
<head>\r
  <title>=E6=97=A5=E6=9C=AC=E8=AA=9E=E3=82=BF=E3=82=A4=E3=83=88=E3=83=AB</t=\r
itle>\r
</head>\r
<body>\r
  <h1>=E8=A6=8B=E5=87=BA=E3=81=97</h1>\r
  <p>=E6=9C=AC=E6=96=87<p>\r
</body>\r
</html>=0D
HTM

    expected = <<-HTM
<html lang=\"ja\">\r
<head>\r
  <title>日本語タイトル</title>\r
</head>\r
<body>\r
  <h1>見出し</h1>\r
  <p>本文<p>\r
</body>\r
</html>\r
HTM

    decoded = RMail::Utils.quoted_printable_decode(encoded)
    decoded.should eq(expected)
  end

end

