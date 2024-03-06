require "./widget.cr"
require "./util.cr"

module Redwood

class HorizontalSelector
  class UnknownValue < StandardError; end

  property label : String
  property changed_by_user : Bool
  property selection : Int32

  def initialize(@label, vals : Array(String), labels : Array(String), 
		 base_color=:horizontal_selector_unselected_color,
		 selected_color=:horizontal_selector_selected_color)
    @vals = vals
    @labels = labels
    @base_color = base_color
    @selected_color = selected_color
    @selection = 0
    @changed_by_user = false
  end

  def set_to(val)
    if i = @vals.index(val)
      @selection = i
    else
      raise UnknownValue.new(val.inspect)
    end
  end

  def can_set_to?(val)
    !@vals.index(val).nil?
  end

  def val; @vals[@selection] end

  def line(width=nil) : WidgetArray
    label =
      if width
        @label.pad_left(width)
      else
        "#{@label} "
      end

    l = WidgetArray.new
    l << {@base_color, label}
    @labels.each_with_index do |label, i|
      if i == @selection
	l << {@selected_color, label}
      else
	l << {@base_color, label}
      end
      l << {@base_color, "  "}
    end
    l << {@base_color, ""}
    return l
  end

  def roll_left
    @selection = (@selection - 1) % @labels.size
    @changed_by_user = true
  end

  def roll_right
    @selection = (@selection + 1) % @labels.size
    @changed_by_user = true
  end
end

end
