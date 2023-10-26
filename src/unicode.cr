require "ncurses"

lib LibC
  alias WChar = UInt32

  fun wcswidth(s : WChar*, n : SizeT) : Int
  fun wcwidth(c : WChar) : Int
end

module Unicode
  extend self

  # cjk is ignored, but present for Ruby compatibility
  def width(s : String, cjk : Bool = false) : Int32
    width = 0
    chreader = Char::Reader.new(s)
    chreader.each do |ch|
      wc : LibC::WChar = ch.ord.to_u
      wclen = LibC.wcwidth(wc)
      if wclen < 0
	wclen = 1
      end
      width += wclen
    end
    width
  end

end
