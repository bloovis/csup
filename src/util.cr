require "./unicode.cr"

class String
  def display_length
    Unicode.width(self,false)
  end
end
