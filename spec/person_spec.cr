require "./spec_helper"
require "../src/person"

describe Person do
  it "creates a person with a name" do
    p = Person.new("Mark Alexander", "marka@pobox.com")
    p.nil?.should eq(false)
    p.to_s.should eq("Mark Alexander <marka@pobox.com>")
  end

  it "creates a person with no name" do
    p = Person.new(nil, "noname@pobox.com")
    p.nil?.should eq(false)
    p.to_s.should eq("noname@pobox.com")
  end

  it "creates a person from address with no name" do
    p = Person.from_address("marka@pobox.com")
    p.nil?.should eq(false)
    p.to_s.should eq("marka <marka@pobox.com>")
  end

  it "creates a person from address with name" do
    p = Person.from_address("\"A real somebody!\" <somebody@pobox.com>")
    p.nil?.should eq(false)
    p.to_s.should eq("A real somebody! <somebody@pobox.com>")
  end
end
