require "../keymap"
require "../buffer"
require "../mode"
require "../config"
require "../supcurses"
require "../opts"
require "../widget"

module Redwood

class ScrollMode < Mode
  mode_class line_down, line_up, col_left, col_right, page_down,
	     page_up, half_page_down, half_page_up, jump_to_start,
	     jump_to_end, jump_to_left, search_in_buffer,
	     continue_search_in_buffer

  ## we define topline and botline as the top and bottom lines of any
  ## content in the currentview.

  ## we left leftcol and rightcol as the left and right columns of any
  ## content in the current view. but since we're operating in a
  ## line-centric fashion, rightcol is always leftcol + the buffer
  ## width. (whereas botline is topline + at most the buffer height,
  ## and can be == to topline in the case that there's no content.)

  property status = ""
  property topline = 0
  property botline = 0
  property leftcol = 0
  @search_query : String?
  @search_line : Int32?

  register_keymap do |k|
    k.add :line_down, "Down one line", "Down", "j", "J", "C-e"
    k.add :line_up, "Up one line", "Up", "k", "K", "C-y"
    k.add :col_left, "Left one column", "Left", "h"
    k.add :col_right, "Right one column", "Right", "l"
    k.add :page_down, "Down one page", "PgDn", " ", "C-f"
    k.add :page_up, "Up one page", "PgUp", "p", "C-h", "C-b"
    k.add :half_page_down, "Down one half page", "C-d"
    k.add :half_page_up, "Up one half page", "C-u"
    k.add :jump_to_start, "Jump to top", "Home", "^", "1"
    k.add :jump_to_end, "Jump to bottom", "End", "$", "0"
    k.add :jump_to_left, "Jump to the left", "["
    k.add :search_in_buffer, "Search in current buffer", "/"
    k.add :continue_search_in_buffer, "Jump to next search occurrence in buffer",
	  BufferManager::CONTINUE_IN_BUFFER_SEARCH_KEY
  end

  def initialize(opts = Opts.new)
    @topline, @botline, @leftcol = 0, 0, 0
    @slip_rows = opts.int(:slip_rows) || 0 # when we pgup/pgdown,
					   # how many lines do we keep?
    @twiddles = opts.member?(:twiddles) ? opts.bool(:twiddles) : true
    @search_query = nil
    @search_line = nil
    @status = ""
    super()
  end

  # Subclasses must provide these methods.
  def [](i : Int32) : Text
    ""
  end

  def lines
    0
  end

  def rightcol; @leftcol + buffer.content_width; end

  def draw
    ensure_mode_validity
    (@topline ... @botline).each { |ln| draw_line(ln, Opts.new({:color => :text_color})) }
    ((@botline - @topline) ... buffer.content_height).each do |ln|
      if @twiddles
        buffer.write ln, 0, "~", Opts.new({:color => :twiddle_color})
      else
        buffer.write ln, 0, "", Opts.new({:color => :text_color})
      end
    end
  end

  def in_search?; @search_line end
  def cancel_search!; @search_line = nil end

  def continue_search_in_buffer(*args)
    unless @search_query
      BufferManager.flash "No current search!"
      return
    end

    start = @search_line || search_start_line
    query = @search_query || ""
    line, col = find_text(query || "", start)
    if line == -1 && start > 0
      line, col = find_text query, 0
      BufferManager.flash "Search wrapped to top!" if line != -1
    end
    if line != -1
      @search_line = line + 1
      search_goto_pos line, col, col + query.display_length
      buffer.mark_dirty
    else
      BufferManager.flash "Not found!"
    end
  end

  def search_in_buffer(*args)
    query = BufferManager.ask :search, "search in buffer: "
    return if query.nil? || query.empty?
    @search_query = Regex.escape query
    continue_search_in_buffer
  end

  ## subclasses can override these three!
  def search_goto_pos(line, leftcol, rightcol)
    search_goto_line line

    if rightcol > self.rightcol # if it's occluded...
      jump_to_col [rightcol - buffer.content_width + 1, 0].max # move right
    end
  end
  def search_start_line; @topline end
  def search_goto_line(line); jump_to_line line end

  def col_jump
    Config.int(:col_jump) || 2
  end

  def col_left(*args)
    return unless @leftcol > 0
    @leftcol -= col_jump
    buffer.mark_dirty
  end

  def col_right(*args)
    @leftcol += col_jump
    buffer.mark_dirty
  end

  def jump_to_col(col)
    col = col - (col % col_jump)
    buffer.mark_dirty unless @leftcol == col
    @leftcol = col
  end

  def jump_to_left(*args); jump_to_col 0; end

  ## set top line to l
  def jump_to_line(l)
    l = l.clamp 0, lines - 1
    return if @topline == l
    @topline = l
    @botline = [l + buffer.content_height, lines].min
    buffer.mark_dirty
    @status = "lines #{@topline + 1}:#{@botline}/#{lines}"
  end

  def at_top?; @topline == 0 end
  def at_bottom?; @botline == lines end

  def line_down(*args); jump_to_line @topline + 1; end
  def line_up(*args);  jump_to_line @topline - 1; end
  def page_down(*args)
    jump_to_line @topline + buffer.content_height - @slip_rows
  end
  def page_up(*args)
    jump_to_line @topline - buffer.content_height + @slip_rows
  end
  def half_page_down(*args)
    jump_to_line @topline + buffer.content_height // 2
  end
  def half_page_up(*args)
    jump_to_line @topline - buffer.content_height // 2
  end
  def jump_to_start(*args); jump_to_line 0; end
  def jump_to_end(*args); jump_to_line lines - buffer.content_height; end

  def ensure_mode_validity
    @topline = @topline.clamp 0, [lines - 1, 0].max
    height = buffer.content_height
    @botline = [@topline + height, lines].min
  end

  def resize(rows, cols)
    super(rows, cols)
    ensure_mode_validity
  end

  protected def find_text(query, start_line)
    regex = /#{query}/i
    (start_line ... lines).each do |i|
      case(s = self[i])
      when String
        match = s =~ regex
        return [i, match] if match
      when Array
        offset = 0
        s.each do |text|
          color = text[0]
	  string = text[1]
          match = string =~ regex
          if match
            return {i, offset + match}
          else
            offset += string.display_length
          end
        end
      end
    end
    return {-1, -1}
  end

  protected def draw_line(ln, opts = Opts.new)
    regex = /(#{@search_query})/i
    case(s = self[ln])
    when String
      if in_search?
        draw_line_from_array ln, matching_text_array(s, regex), opts
      else
        draw_line_from_string ln, s, opts
      end
    when Array
      if in_search?
        ## seems like there ought to be a better way of doing this
        array = WidgetArray.new
        s.each do |color, text|
          if text =~ regex
            array += matching_text_array text, regex, color
          else
            array << {color, text}
          end
        end
        draw_line_from_array ln, array, opts
      else
        draw_line_from_array ln, s, opts
      end
    else
      raise "unknown drawable object: #{s.inspect} in #{self} for line #{ln}" # good for debugging
    end

      ## speed test
      # str = s.map { |color, text| text }.join
      # buffer.write ln - @topline, 0, str, color: none, highlight: highlight
      # return
  end

  protected def matching_text_array(s, regex, oldcolor=:text_color) : WidgetArray
    s.split(regex).map do |text|
      next if text.empty?
      if text =~ regex
        {:search_highlight_color, text}
      else
        {oldcolor, text}
      end
    end.compact + [{oldcolor, ""}]
  end

  protected def draw_line_from_array(ln : Int32, a : WidgetArray, opts : Opts)
    xpos = 0
    a.each_with_index do |line, i|
      color = line[0]
      text = line[1]
      raise "nil text for color '#{color}'" if text.nil? # good for debugging
      l = text.display_length
      no_fill = i != a.size - 1

      if xpos + l < @leftcol
        buffer.write ln - @topline, 0, "",
		     Opts.new({:color => color || :none,
			       :highlight => opts.bool(:highlight) || false})
      elsif xpos < @leftcol
        ## partial
        buffer.write ln - @topline, 0, text[(@leftcol - xpos) .. -1],
		     Opts.new({:color => color || :none,
			       :highlight => opts.bool(:highlight) || false,
			       :no_fill => no_fill})
      else
        buffer.write ln - @topline, xpos - @leftcol, text,
		     Opts.new({:color => color || :none,
			       :highlight => opts.bool(:highlight) || false,
			       :no_fill => no_fill})
      end
      xpos += l
    end
  end

  protected def draw_line_from_string(ln : Int32, s : String, opts : Opts)
    buffer.write ln - @topline, 0, s[@leftcol .. -1]? || "",
		 Opts.new({:highlight => opts.bool(:highlight) || false,
			   :color => opts.sym(:color) || :none})
  end

end

end

