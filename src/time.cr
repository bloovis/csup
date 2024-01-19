require "./util"
require "./config"

struct Time
  def self.now
    local
  end

  def to_i
    to_unix
  end

  def strftime(format)
    to_s(format)
  end

  def to_indexable_s
    sprintf "%012d", self.to_unix
  end

  def nearest_hour
    if minute < 30
      self
    else
      self + Time::Span.new(minutes: 60 - minute)
    end
  end

  def midnight # within a second
    self - Time::Span.new(hours: hour, minutes: minute, seconds: second)
  end

  def is_the_same_day?(other : Time)
    (midnight - other.midnight).to_i.abs < 1
  end

  def is_the_day_before?(other : Time)
    (0..24 * 60 * 60 + 1).includes?((other.midnight - midnight).to_i)
  end

  def to_nice_distance_s(from = Time.local)
    diff_i = self.to_unix - from.to_unix
    later_than = diff_i < 0
    diff = diff_i.abs.to_f
    text =
      [ ["second", 60],
        ["minute", 60],
        ["hour", 24],
        ["day", 7],
        ["week", 4.345], # heh heh
        ["month", 12],
        ["year", nil],
      ].argfind do |x|
        unit = x[0]
	size = x[1]
        if diff.round <= 1
          "one #{unit}"
        elsif size.nil? || diff.round < size.to_f
          "#{diff.round.to_i} #{unit}s"
        else
          diff /= size.to_f
          false
        end
      end
    text = text.as(String)
    if later_than
      text + " ago"
    else
      "in " + text
    end
  end

  TO_NICE_S_MAX_LEN = 9 # e.g. "Yest.10am"

  ## This is how a thread date is displayed in thread-index-mode
  def to_nice_s(from=Time.local)
    default_to_nice_s(from)
  end

  def default_to_nice_s(from=Time.local)
    if year != from.year
      strftime "%b %Y"
    elsif month != from.month
      strftime "%b %e"
    else
      if Redwood::Config.has_key?(:time_mode)
        time_mode = Redwood::Config.str(:time_mode)
      else
	time_mode = ""
      end
      if is_the_same_day?(from)
	format = time_mode == "24h" ? "%k:%M" : "%l:%M%p"
        strftime(format).downcase
      elsif is_the_day_before? from
        format = time_mode == "24h" ? "%kh" : "%l%p"
        "Yest." + nearest_hour.strftime(format).downcase
      else
        strftime "%b %e"
      end
    end
  end

  ## This is how a message date is displayed in thread-view-mode
  def to_message_nice_s(from=Time.local)
    if Redwood::Config.has_key?(:time_mode)
      time_mode = Redwood::Config.str(:time_mode)
    else
      time_mode = ""
    end
    format = time_mode == "24h" ? "%B %e %Y %k:%M" : "%B %e %Y %l:%M%p"
    strftime format
  end
end

