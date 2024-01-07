require "../src/config"
require "../src/time"

module Redwood

c = Config.new

def self.test_span(t : Time, span : Time::Span)
  puts "---\nnice t = " + t.to_nice_s
  puts "t = #{t}"
  puts "t midnight = #{t.midnight}"

  puts "Positive span:\n"
  u = t + span
  puts "u = #{u}"
  puts "u midnight = #{u.midnight}"
  puts "midnight difference = #{(t.midnight - u.midnight).to_i}"
  puts "nice u = " + u.to_nice_s
  puts u.to_nice_distance_s(t)

  puts "Negative span:\n"
  u = t - span
  puts "u = #{u}"
  puts "u midnight = #{u.midnight}"
  puts "midnight difference = #{(t.midnight - u.midnight).to_i}"
  puts "nice u = " + u.to_nice_s
  puts u.to_nice_distance_s(t)
end


def self.test
t = Time.now
  test_span(t, Time::Span.new(minutes: 23))
  test_span(t, Time::Span.new(minutes: 980))
  test_span(t, Time::Span.new(days: 22))
  test_span(t, Time::Span.new(days: 170))
end

test

end	# Redwood
