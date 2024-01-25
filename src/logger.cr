require "./singleton"
require "./modes/log_mode"

module Redwood

## simple centralized logger. outputs to multiple sinks by calling << on them.
## also keeps a record of all messages, so that adding a new sink will send all
## previous messages to it by default.
class Logger
  singleton_class

  alias Sink = IO | LogMode

  LEVELS = %w(debug info warn error) # in order!

  @level = 0

  def initialize(level = "info")
    singleton_pre_init
    if ENV.has_key?("CSUP_LOG_LEVEL")
      level = ENV["CSUP_LOG_LEVEL"]
    end
    set_level(level)
    #@mutex = Mutex.new
    @buf = IO::Memory.new
    @sinks = [] of Sink
    singleton_post_init
  end

  def level
    LEVELS[@level]
  end
  singleton_method level

  def set_level(level)
    @level = LEVELS.index(level) ||
      raise ArgumentError.new("invalid log level #{level.inspect}: should be one of #{LEVELS.join(", ")}")
  end

  def Logger.level=(level)
    self.instance.set_level(level)
  end

  def add_sink(s : Sink, copy_current=true)
    #@mutex.synchronize do
      @sinks << s
      #STDERR.puts "add_sink: adding sink #{s.class.name}"
      s << @buf.to_s if copy_current
    #end
  end
  singleton_method add_sink, s

  def remove_sink(s)
    #@mutex.synchronize do
      @sinks.delete s
    #end
  end
  singleton_method remove_sink, s

  def remove_all_sinks!
    #@mutex.synchronize do
      @sinks.clear
    #end
  end
  singleton_method remove_all_sinks!

  def clear!
    #@mutex.synchronize do
      @buf = IO::Memory.new
    #end
  end
  singleton_method clear!

  {% for level,index in LEVELS %}
    def {{level.id}}(s : String)
      if {{index}} >= @level
	send_message(format_message({{level}}, Time.local, s))
      end
    end
    singleton_method {{level.id}}, s
  {% end %}

#  LEVELS.each_with_index do |l, method_level|
#    define_method(l) do |s|
#      if method_level >= @level
#        send_message format_message(l, Time.now, s)
#      end
#    end

  ## send a message regardless of the current logging level
  def force_message(m)
    send_message(format_message("", Time.now, m))
  end
  singleton_method force_message, m


  ## level can be nil!
  private def format_message(level, time, msg)
    prefix = case level
      when "warn"; "WARNING: "
      when "error"; "ERROR: "
      else ""
    end
    "[#{time.to_s}] #{prefix}#{msg.rstrip}\n"
  end

  ## actually distribute the message
  private def send_message(m)
    #@mutex.synchronize do
      @sinks.each do |sink|
        sink << m
        sink.flush if sink.responds_to?(:flush) && level == "debug"
      end
      @buf << m
    #end
  end

end	# class Logger

end	# module Redwood

# Define top-level debug, info, etc. methods
{% for level in Redwood::Logger::LEVELS %}
  def {{level.id}}(s : String)
    Redwood::Logger.{{level.id}}(s)
  end
{% end %}
