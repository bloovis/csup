require "./scroll_mode"

module Redwood

class CompletionMode < ScrollMode
  mode_class

  INTERSTITIAL = "  "

  def initialize(list : Array(String), opts=Opts.new{})
    @list = list
    @header = opts.str(:header)
    @prefix_len = opts.int(:prefix_len)
    @lines = TextLines.new
    super(Opts.new({:slip_rows => 1, :twiddles => false}))
  end

  def lines
    if @lines.size == 0
      update_lines
    end
    @lines.size
  end

  def [](i)
    if @lines.size == 0
      update_lines
    end
    @lines[i]? || ""
  end

  def roll
    if at_bottom?
      jump_to_start
    else
      page_down
    end
  end

#private

  def update_lines
    width = buffer.content_width
    max_length = @list.max_of { |s| s.length }
    num_per = [1, buffer.content_width // (max_length + INTERSTITIAL.length)].max
    @lines = TextLines.new
    if h = @header
      @lines << h
    end
    widgets = WidgetArray.new
    @list.each_with_index do |s, i|
      if i % num_per == 0
	if widgets.size > 0
	  @lines << widgets
	  widgets = WidgetArray.new
	end
      end
      if (plen = @prefix_len) && (plen > 0)
        if plen < s.length
          prefix = s[0 ... plen]
          suffix = s[(plen + 1) .. -1]
          char = s[plen].to_s

          widgets << {:text_color, sprintf("%#{max_length - suffix.length - 1}s", prefix)}
	  widgets << {:completion_character_color, char}
	  widgets << {:text_color, suffix + INTERSTITIAL}
        else
          widgets << {:text_color, sprintf("%#{max_length}s#{INTERSTITIAL}", s)}
        end
      else
        widgets << {:text_color, sprintf("%#{max_length}s#{INTERSTITIAL}", s)}
      end
    end
    if widgets.size > 0
      @lines << widgets
    end
  end

end	# CompletionMode

end	# Redwood
