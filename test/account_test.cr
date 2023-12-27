require "../src/account"
require "../src/supcurses"
require "../src/person"

module Redwood

cm = Config.new
am = AccountManager.new(Config.accounts)

puts "Account emails:"
AccountManager.user_emails.each do |email|
  puts "----\nAccount: #{email}"
  p = Person.new("somebody", email)
  is_account = AccountManager.is_account?(p)
  if is_account
    puts "Person for #{email} has an account.  Good."
  else
    puts "Person for #{email} does not have an account! Bad!"
  end
  is_account_email = AccountManager.is_account_email?(email)
  if is_account_email
    puts "Email #{email} has an account.  Good."
  else
    puts "Email #{email} does not have an account! Bad!"
  end
  a = AccountManager.account_for(email)
  if a
    puts "Email #{email} account: #{a.inspect}"
  else
    puts "Email #{email} does not have an account! Bad!"
  end
  full = AccountManager.full_address_for(email)
  if full
    puts "Email #{email} has full address #{full}"
  else
    puts "Email #{email} does not have a full address! Bad!"
  end
  a = AccountManager.account_for(email)
  if a
    puts "Email #{email} account: #{a.inspect}"
  else
    puts "Email #{email} does not have an account! Bad!"
  end

end

end	# Redwood

