# Lines of text in any mode derived from ScrollMode are an array of either:
# - a String, which is displayed using a default color
# - an Array of Widgets
# A Widget is a String annotated with a Symbol representing its color.
# A single line in the display can be made up of multiple Widgets, theoretically
# allowing every character on the line to have its own color.

module Redwood

alias Widget = Tuple(Symbol, String)	# {color, text}
alias WidgetArray = Array(Widget)
alias Text = WidgetArray | String
alias TextLines = Array(Text)

end
