require "../src/csup"
require "../src/supcurses"

module Redwood

class Config
  def test_setup
    @entries["editor"] = ENV["EDITOR"]
    account = Account.new
    account["name"] = "Hunter Biden"
    account["email"] = "hbiden@rosemontseneca.com"
    accounts = Accounts.new
    accounts["default"] = account
    @entries["accounts"] = accounts
    @entries["poll_interval"] = 300
    @entries["patchwork"] = false
    @entries["hidden_labels"] = ["spam", "deleted"]
  end
end

def self.print_config
  puts "Full name = #{@@config.get_gecos}"
  editor = Config.str(:editor)
  puts "editor = #{editor}"

  default = Config.account(:default)
  puts "default account #{default.inspect}"
  name = default["name"]
  email = default["email"]
  puts "default name: #{name}, email #{email}"

  Config.accounts.each do |a|
    puts "Account: #{a.inspect}"
  end

  poll_interval = Config.int(:poll_interval)
  puts "poll_interval = #{poll_interval}"

  patchwork = Config.bool(:patchwork)
  puts "patchwork = #{patchwork}"

  hidden_labels = Config.strarray(:hidden_labels)
  hidden_labels.each {|label| puts "hidden label: #{label}"}
end

puts "---- Testing config from ~/.csup/config.yaml ----"
@@config = Config.new(File.join(BASE_DIR, "config.yaml"))
print_config

puts "---- Testing Hunter Biden test config ----"
@@config.test_setup
print_config

end	# Redwood
