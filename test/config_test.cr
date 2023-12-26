require "../src/config"

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

@@config = Config.new
puts @@config.get_gecos
@@config.test_setup

editor = Config.str(:editor)
puts "editor = #{editor}"

hunter = Config.account(:default)
puts "hunter (#{hunter.class.name}) = #{hunter.inspect}"

poll_interval = Config.int(:poll_interval)
puts "poll_interval = #{poll_interval}"

patchwork = Config.bool(:patchwork)
puts "patchwork = #{patchwork}"

hidden_labels = Config.strarray(:hidden_labels)
hidden_labels.each {|label| puts "hidden label: #{label}"}

end	# Redwood
