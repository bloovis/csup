require "./person"
require "./singleton"

module Redwood

class ContactManager
  singleton_class ContactManager

  @fn = ""
  @p2a = {} of Person => String		# person to alias
  @a2p = {} of String => Person		# alias to person
  @e2p = {} of String => Person		# email to person

  def initialize(fn : String)
    singleton_pre_init
    @fn = fn
    if File.exists?(fn)
      File.each_line(fn) do |l|
        if l =~ /^([^:]*):\s*(.*)$/
          aalias, addr = $1, $2
          update_alias(Person.from_address(addr), aalias)
	else
	  raise "can't parse #{fn} line #{l.inspect}"
	end
      end
    end
    singleton_post_init
  end

  def contacts
    @p2a.keys
  end
  singleton_method contacts

  def contacts_with_aliases
    @a2p.values.uniq
  end
  singleton_method contacts_with_aliases

  def update_alias(person : Person, aalias : (String | Nil) = nil)
    ## Deleting old data if it exists
    old_aalias = @p2a[person]?
    if old_aalias
      @a2p.delete old_aalias
      @e2p.delete person.email
    end
    ## Update with new data
    @p2a[person] = aalias
    unless aalias.nil? || aalias.empty?
      @a2p[aalias] = person
      @e2p[person.email] = person
    end
  end
  singleton_method update_alias, person, aalias

  def contact_for(aalias)
    @a2p[aalias]?
  end
  singleton_method contact_for, aalias

  def alias_for(person)
    @p2a[person]?
  end
  singleton_method alias_for, person

  def person_for(email)
    @e2p[email]?
  end
  singleton_method person_for, email

  def is_aliased_contact?(person)
    !@p2a[person].nil?
  end
  singleton_method is_aliased_contact?, person

  def save
    File.open(@fn, "w") do |f|
      @p2a.to_a.sort_by { |t| {t[0].full_address, t[1]} }.each do |t|
        f.puts "#{t[1] || ""}: #{t[0].full_address}"
      end
    end
  end
  singleton_method save

end	# class ContactManager

end	# module Redwood

