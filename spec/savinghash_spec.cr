require "./spec_helper"
require "../src/util"

class C
  property val
  def initialize; @val = 0 end
end

describe Hash do
  it "does not save newly created values" do
    h1 = Hash(Symbol, C).new {C.new}
    h1[:a].val.should eq(0)
    h1[:a].val = 1
    h1[:a].val.should eq(0)
  end
end

describe SavingHash do
  it "saves newly created values" do
    h1 = SavingHash(Symbol, C).new {C.new}
    h1[:a].val.should eq(0)
    h1[:a].val = 1
    h1[:a].val.should eq(1)
  end
end
