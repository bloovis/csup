require "./line_cursor_mode"

module Redwood

@@recent = ""

def recent=(s)
  @@recent = s
end

def recent
  @@recent
end

## meant to be spawned via spawn_modal!
class FileBrowserMode < LineCursorMode

  mode_class back, view, select_file_or_follow_directory, reload, go_recent

  RESERVED_ROWS = 1

  register_keymap do |k|
    k.add :back, "Go back to previous directory", "B"
    k.add :view, "View file", "v"
    k.add :select_file_or_follow_directory, "Select the highlighted file, or follow the directory", "C-m"
    k.add :reload, "Reload file list", "R"
    k.add :go_recent, "Go to last directory seen", "l"
  end

  bool_property done
  property value = ""
  property dirs = Array(String).new
  property text = TextLines.new
  property files = Array(Tuple(String, String)).new
  property recent = ""

  def initialize(dir=".")
    @dirs << Path.new(dir).expand.to_s
    @done = false
    @value = ""
    regen_text
    super(Opts.new({:skip_top_rows => RESERVED_ROWS}))
  end

  def cwd; @dirs.last end
  def lines; @text.length; end
  def [](i); @text[i]; end

#protected

  def back(*args)
    return if @dirs.size == 1
    @dirs.pop
    reload
  end

  def reload(*args)
    regen_text
    jump_to_start
    buffer.mark_dirty
  end

  def view(*args)
    t = @files[curpos - RESERVED_ROWS]
    name = t[0]
    f = t[1]
    return unless f && File.file?(f)

    begin
      BufferManager.spawn f.to_s, TextMode.new(File.read(f))
    rescue e
      BufferManager.flash e.message || "Unknown error reading #{f}"
    end
  end

  def select_file_or_follow_directory(*args)
    t = @files[curpos - RESERVED_ROWS]
    name = t[0]
    f = t[1]
    #STDERR.puts "select: name = #{name}, f = #{f}"
    return unless f

    if File.directory?(f) && name != "./"
      if File.readable?(f)
        @dirs.push f
        reload
      else
        BufferManager.flash "Permission denied - #{f}"
      end
    else
      Redwood.recent = cwd
      @value = f
      @done = true
    end
  end

  def file_human_size(path : String) : String
    begin
      File.size(path).to_human_size
    rescue
      "0"
    end
  end

  def file_human_time(path : String) : String
    begin
      File.info(path).modification_time.to_s("%Y-%m-%d %H:%M")
    rescue
      "0000-00-00 00:00"
    end
  end

  def regen_text
    d = Dir.new(cwd)

    # Create unsorted list of file tuples {basename, fullpath}
    filenames = Array(Tuple(String,String)).new
    d.each do |f|
      filenames << {f, Path[cwd, f].expand.to_s}
    end

    # Sort the file tuples so that directories go first, then sort by name.
    s = filenames.sort do |a, b|
      apath = a[1]
      bpath = b[1]
      adir = File.directory?(apath) ? 0 : 1
      bdir = File.directory?(bpath) ? 0 : 1
      if adir == bdir
	a[0] <=> b[0]
      else
	adir <=> bdir
      end
    end

    # Now construct the new sorted list with the basenames annotated
    # if they are directories or symlinks.
    @files = s.map do |f|
      name = f[0]
      real_f = f[1]
      if File.directory?(real_f)
	name = name + "/"
      elsif File.symlink?(real_f)
	name = name + "@"
      end
      {name, real_f}
    end

    size_width = @files.max_of { |f| file_human_size(f[1]).size }
    time_width = @files.max_of { |f| file_human_time(f[1]).size }

    @text = TextLines.new
    @text << "#{cwd}:"
    @files.each do |t|
      name = t[0]
      f = t[1]
      @text << file_human_time(f).pad_left(time_width) + " " +
	       file_human_size(f).pad_left(size_width) + " " +
	       name
    end
  end

  def go_recent(*args)
    return if Redwood.recent.empty?
    @dirs.push(Redwood.recent)
    reload
  end
    
end

end
