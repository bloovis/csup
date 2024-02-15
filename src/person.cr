require "./contact"

module Redwood

class Person
  property name : (String | Nil)
  property email : String

  def initialize(name : (String | Nil), email : String)
    if name
      name = name.strip.gsub(/\s+/, " ")
      name =~ /^(['"]\s*)(.*?)(\s*["'])$/ ? $2 : name
      name.gsub("\\\\", "\\")
    end
    @name = name
    @email = email.strip.gsub(/\s+/, " ")
  end

  def to_s
    if @name
      "#{@name} <#{@email}>"
    else
      @email
    end
  end

  def shortname
    case @name
    when /\S+, (\S+)/
      $1
    when /(\S+) \S+/
      $1
    when nil
      @email
    else
      @name
    end
  end

  def mediumname; @name || @email; end

  def longname
    to_s
  end

  def full_address
    Person.full_address @name, @email
  end

  ## when sorting addresses, sort by this
  def sort_by_me
    name = @name || ""
    case name
    when /^(\S+), \S+/
      $1
    when /^\S+ \S+ (\S+)/
      $1
    when /^\S+ (\S+)/
      $1
    when ""
      @email || ""
    else
      name
    end.downcase
  end

  # Class methods

  def self.from_name_and_email(name : (String | Nil), email : String)
    if ContactManager.instantiated?
      p = ContactManager.person_for(email)
      return p if p
    end
    Person.new(name, email)
  end

  def self.full_address(name : (String | Nil), email : (String | Nil))
    if name && email
      if name =~ /[",@]/
	"#{name.inspect} <#{email}>" # escape quotes
      else
	"#{name} <#{email}>"
      end
    else
      email
    end
  end

  def self.from_address(s : String)
    ## try and parse an email address and name
    name, email = case s
      when /(.+?) ((\S+?)@\S+) \3/
	## ok, this first match cause is insane, but bear with me.  email
	## addresses are stored in the to/from/etc fields of the index in a
	## weird format: "name address first-part-of-address", i.e.  spaces
	## separating those three bits, and no <>'s. this is the output of
	## #indexable_content. here, we reverse-engineer that format to extract
	## a valid address.
	##
	## we store things this way to allow searches on a to/from/etc field to
	## match any of those parts. a more robust solution would be to store a
	## separate, non-indexed field with the proper headers. but this way we
	## save precious bits, and it's backwards-compatible with older indexes.
	{$1, $2}
      when /["'](.*?)["'] <(.*?)>/, /([^,]+) <(.*?)>/
	a, b = $1, $2
	{a.gsub("\\\"", "\""), b}
      when /<((\S+?)@\S+?)>/
	{$2, $1}
      when /((\S+?)@\S+)/
	{$2, $1}
      else
	{nil, s}
      end

    self.from_name_and_email name, email
  end

  # Return an array of Person objects for a
  # string of comma-separated email address.
  def self.from_address_list(ss : String?) : Array(Person)
    return Array(Person).new if ss.nil?
    ss.split_on_commas.map { |s| self.from_address s }
  end


end	# class Person

end	# module Redwood
