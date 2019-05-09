require "ncurses"

lib LibC
  alias WChar = UInt32

  fun wcswidth(s : WChar*, n : SizeT) : Int
end

module Unicode
  extend self

  # cjk is ignored, but present for Ruby compatibility
  def width(s : String, cjk : Bool = false) : Int32
    #puts "Determining width of #{s}"
    width = 0
    chreader = Char::Reader.new(s)
    chreader.each do |ch|
      #puts "ch = #{ch}(#{ch.ord})"
      wc : LibC::WChar = ch.ord.to_u
      wclen = LibC.wcswidth(pointerof(wc), 1)
      if wclen < 0
	wclen = 1
      end
      #puts "wclen = #{wclen}"
      width += wclen
    end
    width
  end

end

LibNCurses.setlocale(0, "")
s = "this is a test"
puts "display width of '#{s}' = #{Unicode.width(s)}"
s = "你好"
puts "display width of '#{s}' = #{Unicode.width(s)}"
