# Class for passing options to methods in Mode and its subclasses.

module Redwood

class Opts
  alias Value = String | Int32 | Bool | Symbol | Array(String)

  def initialize(h = nil)
    @entries = Hash(String, Value).new
    if h
      #puts "Opts.initialize: h = " + h.inspect
      merge(h)
    end
  end

  def []=(key : Symbol | String, value)
    @entries[key.to_s] = value
  end

  def merge(h)
    @entries.merge!(h)
  end

  # Methods for retrieving entries as specific types.
  macro get(name, type)
    def {{name}}(s : Symbol | String) : {{type}}?
      key = s.to_s
      if @entries.has_key?(key)
	return @entries[s.to_s].as({{type}})
      else
	return nil
      end
    end
  end
   
  get(str, String)
  get(int, Int32)
  get(bool, Bool)
  get(sym, Symbol)
  get(strarray, Array(String))

end	# Opts

end	# Redwood

