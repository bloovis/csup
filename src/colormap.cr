require "yaml"

class Colormap
  class ColorEntry
    property fg : Int32
    property bg : Int32
    property attrs : Array(Int32)
    property color : Int32 | Nil

    def initialize(@fg, @bg, @attrs = [] of Int32, @color = nil)
    end
  end

  # Class variables.
  @@instance = nil

  @@default_colors = {
    "text" => { "fg" => "white", "bg" => "black" },
    "status" => { "fg" => "white", "bg" => "blue", "attrs" => ["bold"] },
    "index_old" => { "fg" => "white", "bg" => "default" },
    "index_new" => { "fg" => "white", "bg" => "default", "attrs" => ["bold"] },
    "index_starred" => { "fg" => "yellow", "bg" => "default", "attrs" => ["bold"] },
    "index_draft" => { "fg" => "red", "bg" => "default", "attrs" => ["bold"] },
    "labellist_old" => { "fg" => "white", "bg" => "default" },
    "labellist_new" => { "fg" => "white", "bg" => "default", "attrs" => ["bold"] },
    "twiddle" => { "fg" => "blue", "bg" => "default" },
    "label" => { "fg" => "yellow", "bg" => "default" },
    "message_patina" => { "fg" => "black", "bg" => "green" },
    "alternate_patina" => { "fg" => "black", "bg" => "blue" },
    "missing_message" => { "fg" => "black", "bg" => "red" },
    "attachment" => { "fg" => "cyan", "bg" => "default" },
    "cryptosig_valid" => { "fg" => "yellow", "bg" => "default", "attrs" => ["bold"] },
    "cryptosig_valid_untrusted" => { "fg" => "yellow", "bg" => "blue", "attrs" => ["bold"] },
    "cryptosig_unknown" => { "fg" => "cyan", "bg" => "default" },
    "cryptosig_invalid" => { "fg" => "yellow", "bg" => "red", "attrs" => ["bold"] },
    "generic_notice_patina" => { "fg" => "cyan", "bg" => "default" },
    "quote_patina" => { "fg" => "yellow", "bg" => "default" },
    "sig_patina" => { "fg" => "yellow", "bg" => "default" },
    "quote" => { "fg" => "yellow", "bg" => "default" },
    "sig" => { "fg" => "yellow", "bg" => "default" },
    "to_me" => { "fg" => "green", "bg" => "default" },
    "with_attachment" => { "fg" => "green", "bg" => "default" },
    "starred" => { "fg" => "yellow", "bg" => "default", "attrs" => ["bold"] },
    "starred_patina" => { "fg" => "yellow", "bg" => "green", "attrs" => ["bold"] },
    "alternate_starred_patina" => { "fg" => "yellow", "bg" => "blue", "attrs" => ["bold"] },
    "snippet" => { "fg" => "cyan", "bg" => "default" },
    "option" => { "fg" => "white", "bg" => "default" },
    "tagged" => { "fg" => "yellow", "bg" => "default", "attrs" => ["bold"] },
    "draft_notification" => { "fg" => "red", "bg" => "default", "attrs" => ["bold"] },
    "completion_character" => { "fg" => "white", "bg" => "default", "attrs" => ["bold"] },
    "horizontal_selector_selected" => { "fg" => "yellow", "bg" => "default", "attrs" => ["bold"] },
    "horizontal_selector_unselected" => { "fg" => "cyan", "bg" => "default" },
    "search_highlight" => { "fg" => "black", "bg" => "yellow", "attrs" => ["bold"] },
    "system_buf" => { "fg" => "blue", "bg" => "default" },
    "regular_buf" => { "fg" => "white", "bg" => "default" },
    "modified_buffer" => { "fg" => "yellow", "bg" => "default", "attrs" => ["bold"] },
    "date" => { "fg" => "white", "bg" => "default"},
    "size_widget" => { "fg" => "white", "bg" => "default"},
  }

  # Instance variables
  @highlights = {} of String => String
  @entries = {} of String => ColorEntry

  def initialize
    raise "only one instance can be created" if @@instance
    @color_pairs = {[Ncurses::COLOR_WHITE, Ncurses::COLOR_BLACK] => 0}
    @users = Hash(Int32, Array(String)).new     # colorpair => [names of colors]
    @next_id = 0
    reset
    @@instance = self
    yield self # if block_given?
  end

  def reset
    @entries = Hash(String, ColorEntry).new
    @highlights = { "none" => highlight_sym("none")}
    @entries[highlight_sym("none")] = highlight_for(Ncurses::COLOR_WHITE,
                                                   Ncurses::COLOR_BLACK,
                                                   [] of Int32)
  end

#  def add sym, fg, bg, attr=nil, highlight=nil
  def add(sym : String, fg : Int32, bg : Int32, attr : Array(Int32), highlight : String | Nil)
    # Ruby raise accepts a second string parameter, not supported in Crystal.
    # How to handle this difference correctly?
    raise "ArgumentError: color for #{sym} already defined" if @entries.has_key?(sym)
    raise "ArgumentError: fg color '#{fg}' unknown" unless (-1...Ncurses.num_colors).includes? fg
    raise "ArgumentError: bg color '#{bg}' unknown" unless (-1...Ncurses.num_colors).includes? bg
    attrs = [attr].flatten.compact

    @entries[sym] = ColorEntry.new(fg, bg, attrs, nil)

    if highlight.nil?
      highlight = highlight_sym(sym)
      @entries[highlight] = highlight_for(fg, bg, attrs)
    end

    @highlights[sym] = highlight
  end

  def highlight_sym(sym : Symbol | String) : String
    if sym.is_a?(Symbol)
      return sym.to_s + "_highlight"
    else
      return sym + "_highlight"
    end
  end

  def highlight_for(fg, bg, attrs)
    hfg =
      case fg
      when Ncurses::COLOR_BLUE
        Ncurses::COLOR_WHITE
      when Ncurses::COLOR_YELLOW, Ncurses::COLOR_GREEN
        fg
      else
        Ncurses::COLOR_BLACK
      end

    hbg =
      case bg
      when Ncurses::COLOR_CYAN
        Ncurses::COLOR_YELLOW
      when Ncurses::COLOR_YELLOW
        Ncurses::COLOR_BLUE
      else
        Ncurses::COLOR_CYAN
      end

    attrs =
      if fg == Ncurses::COLOR_WHITE && attrs.includes?(Ncurses::A_BOLD)
        [Ncurses::A_BOLD]
      else
        case hfg
        when Ncurses::COLOR_BLACK
          [] of Int32
        else
          [Ncurses::A_BOLD]
        end
      end
    return ColorEntry.new(hfg, hbg, attrs)
  end

  def color_for(sym, highlight=false)
    sym = @highlights[sym] if highlight
    return Ncurses::COLOR_BLACK if sym == "none"
    raise ArgumentError, "undefined color #{sym}" unless @entries.member? sym

    ## if this color is cached, return it
    fg, bg, attrs, color = @entries[sym]
    return color if color

    if(cp = @color_pairs[[fg, bg]])
      ## nothing
    else ## need to get a new colorpair
      @next_id = (@next_id + 1) % Ncurses.max_pairs
      @next_id += 1 if @next_id == 0 # 0 is always white on black
      id = @next_id
      debug "colormap: for color #{sym}, using id #{id} -> #{fg}, #{bg}"
      Ncurses.init_pair id, fg, bg or raise ArgumentError,
        "couldn't initialize curses color pair #{fg}, #{bg} (key #{id})"

      cp = @color_pairs[[fg, bg]] = Ncurses.COLOR_PAIR(id)
      ## delete the old mapping, if it exists
      if @users.has_key?(cp)
        u = @users[cp]
	if u
	  u.each do |usym|
            warn "dropping color #{usym} (#{id})"
            @entries[usym].color = nil
	  end
        end
        @users[cp] = [] of String
      end
    end

    ## by now we have a color pair
    color = attrs.inject(cp) { |color, attr| color | attr }
    @entries[sym][3] = color # fill the cache
    # record entry as a user of that color pair
    if @users.has_key?(cp)
      @users[cp] << sym
    else
      @users[cp] = [sym]
    end
    color
  end

  def sym_is_defined(sym)
      return sym if @entries.has_key?(sym)
  end

  # Eventually, the code for obtaining color_fn should be
  # moved to lib/csup.rb.
  def load_user_colors
    base_dir   = File.join(ENV["HOME"], ".csup")
    color_fn   = File.join(base_dir, "colors.yaml")

    yaml = File.open(color_fn) { |f| YAML.parse(f) }
    colors = Hash(String, Hash(String, String | Array(String))).new
    h = yaml.as_h
    h.each do |k, v|
      key = k.as_s
      h1 = v.as_h
      puts "Key: #{key}"
      colors[key] = Hash(String, String | Array(String)).new
      h1.each do |k1, v1|
	key1 = k1.as_s
	if key1 == "attrs"
	  attrs = Array(String).new
	  val1 = v1.as_a
	  val1.each_with_index do |v2, i|
	    val2 = v2.as_s
	    puts "  attr[#{i}] = #{val2}"
	    attrs << val2
	  end
	  colors[key]["attrs"] = attrs
	else
	  val1 = v1.as_s
	  colors[key][key1] = val1
	  puts "  #{key1}=#{val1}"
	end
      end
    end

    puts colors.inspect
    return colors
  end

  ## Try to use the user defined colors, in case of an error fall back
  ## to the default ones.
  def populate_colormap
    user_colors = load_user_colors

    ## Set attachment sybmol to sane default for existing colorschemes
    if user_colors && user_colors.has_key? "to_me"
      user_colors["with_attachment"] = user_colors["to_me"] unless user_colors.has_key? "with_attachment"
    end

    @@default_colors.merge(user_colors).each do |k, v|
      fg = begin
        Ncurses.const_get "COLOR_#{v["fg"].to_s.upcase}"
      rescue NameError
        warn "there is no color named \"#{v["fg"]}\""
        Ncurses::COLOR_GREEN
      end

      bg = begin
        Ncurses.const_get "COLOR_#{v["bg"].to_s.upcase}"
      rescue NameError
        warn "there is no color named \"#{v["bg"]}\""
        Ncurses::COLOR_RED
      end

      attrs = [] of Int32
      if v.has_key?("attrs")
	at = v["attrs"].as(Array(String))
	at.each do |a|
	  begin
	    attrs << Ncurses.const_get "A_#{a.upcase}"
	  rescue NameError
	    warn "there is no attribute named \"#{a}\", using fallback."
	  end
	end
      end
      if v.has_key?("highlight")
	s = v["highlight"].as(String)
	highlight_symbol = s + "_color"
      else
	highlight_symbol = nil
      end
      symbol = k + "_color"
      add symbol, fg, bg, attrs, highlight_symbol
    end
  end

#  def self.instance; @@instance; end
#  def self.method_missing meth, *a
#    Colormap.new unless @@instance
#    @@instance.send meth, *a
#  end
  # Performance shortcut
#  def self.color_for(*a); @@instance.color_for(*a); end
end
