require "./spec_helper"
require "../src/util"

describe SparseArray do
  it "allows creating entries beyond the end" do
    a = SparseArray(String).new
    a.size.should eq(0)
    a << "zero"
    a.size.should eq(1)
    a[3] = "three"
    a.size.should eq(4)
    a[5] = "five"
    a.size.should eq(6)

    a[0].should eq("zero")
    a[1].should eq(nil)
    a[2].should eq(nil)
    a[3].should eq("three")
    a[4].should eq(nil)
    a[5].should eq("five")
  end
end
