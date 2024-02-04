require "json"

# Class for passing options to methods in Mode and its subclasses.

module Redwood

alias HeaderHash = Hash(String, String | Array(String))

class Opts
  alias Value = String | Int32 | Bool | Symbol | Array(String) |
		HeaderHash | JSON::Any

  def initialize(h = nil)
    @entries = Hash(Symbol, Value).new
    if h
      #puts "Opts.initialize: h = " + h.inspect
      merge(h)
    end
  end

  # The following two methods make Opts behave a little more like a Hash.
  def []=(key : Symbol, value)
    @entries[key] = value
  end

  def merge(h)
    @entries.merge!(h)
  end

  # For each possible entry type (other than JSON::Any):
  # - define a method that retrieves an entry of a specific type, or nil if there
  #   is no entry with the specified key.
  # - define a delete_ method that deletes an entry of specific type
  macro get(name, type)
    def {{name}}(key : Symbol) : {{type}}?
      if @entries.has_key?(key)
	return @entries[key].as({{type}})
      else
	return nil
      end
    end
    def delete_{{name}}(key : Symbol | String) : {{type}}?
      if @entries.has_key?(key)
	return @entries.delete(key).as({{type}})
      else
	return nil
      end
    end
  end

  def member?(s : Symbol)
    @entries.has_key?(s)
  end

  get(str, String)
  get(int, Int32)
  get(bool, Bool)
  get(sym, Symbol)
  get(strarray, Array(String))
  get(hash, HeaderHash)

end	# Opts

end	# Redwood

