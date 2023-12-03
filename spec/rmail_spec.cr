require "./spec_helper"
require "../src/rmail/address.cr"

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

