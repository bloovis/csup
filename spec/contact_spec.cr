require "./spec_helper"

describe ContactManager do
  it "creates contacts file" do
    contacts_file = "/tmp/contacts.txt"
    create_contacts(contacts_file)
    File.exists?(contacts_file).should eq(true)
    ContactManager.init(contacts_file)
  end

  it "gets contacts"  do
    count = 0
    ContactManager.contacts.each do |p|
      #puts "Contact person = '#{p.to_s}'"
      count += 1
    end
    count.should eq(3)
  end

  it "gets contacts with alias" do
    count = 0
    ContactManager.contacts_with_aliases.each do |p|
      #puts "Contact person with alias = '#{p.to_s}'"
      isa = ContactManager.is_aliased_contact?(p)
      isa.should eq(true)
      count += 1
    end
    count.should eq(3)
  end

  it "tests aliases" do
    ["self", "potus", "putin"].each do |a|
      p = ContactManager.contact_for(a)
      a1 = ContactManager.alias_for(p)
      a1.should eq(a)
    end
  end

  it "check email for an alias" do
    p = ContactManager.contact_for("self")
    a = ContactManager.alias_for(p)
    a.should eq("self")
    if p
      e = p.email
      e.should eq("marka@pobox.com")
    end
  end

  it "looks up a contact by email" do
    p = ContactManager.person_for("marka@pobox.com")
    isa = ContactManager.is_aliased_contact?(p)
    isa.should eq(true)
    a = ContactManager.alias_for(p)
    a.should eq("self")
  end

  it "adds a new contact" do
    p = Person.new("Joe Blow", "joeblow@example.com")
    ContactManager.contact_for("joeblow").nil?.should eq(true)
    # adding joeblow as alias
    ContactManager.update_alias(p, "joeblow")
  end

  it "checks new contact alias" do
    p = ContactManager.contact_for("joeblow")
    a = ContactManager.alias_for(p)
    a.should eq("joeblow")
    p.nil?.should eq(false)    
    if p
      e = p.email
      e.should eq("joeblow@example.com")
    end
  end

  it "saves contacts and checks for new contact" do
    ContactManager.save
    found = false
    File.each_line("/tmp/contacts.txt") do |line|
      if line == "joeblow: Joe Blow <joeblow@example.com>"
	found = true
      end
    end
    found.should eq(true)
  end

end
