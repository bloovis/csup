require "./person.cr"

module ContactManager
  @@fn = ""
  @@p2a : Hash(Person, String) = {} of Person => String		# person to alias
  @@a2p : Hash(String, Person) = {} of String => Person		# alias to person
  @@e2p : Hash(String, Person) = {} of String => Person		# email to person

  extend self

  def init(fn : String)
    @@fn = fn
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
  end

  def contacts
    @@p2a.keys
  end

  def contacts_with_aliases
    @@a2p.values.uniq
  end

  def update_alias(person : Person, aalias : (String | Nil) = nil)
    ## Deleting old data if it exists
    old_aalias = @@p2a[person]?
    if old_aalias
      @@a2p.delete old_aalias
      @@e2p.delete person.email
    end
    ## Update with new data
    @@p2a[person] = aalias
    unless aalias.nil? || aalias.empty?
      @@a2p[aalias] = person
      @@e2p[person.email] = person
    end
  end

  def contact_for(aalias)
    @@a2p[aalias]
  end

  def alias_for(person)
    @@p2a[person]
  end

  def person_for(email)
    @@e2p[email]
  end

  def is_aliased_contact?(person)
    !@@p2a[person].nil?
  end

  def save
    File.open(@@fn, "w") do |f|
      @@p2a.to_a.sort_by { |t| {t[0].full_address, t[1]} }.each do |t|
        f.puts "#{t[1] || ""}: #{t[0].full_address}"
      end
    end
  end

end
