require "./singleton"

module Redwood

class Config
  singleton_class(Config)

  alias Account = Hash(String, String)
  alias Accounts = Hash(String, Account)

  alias ConfigEntry = String | Int32 | Bool | Hash(String, String) | Array(String) |
		      Accounts # Account information

  @entries = Hash(String, ConfigEntry).new

  def initialize
    singleton_pre_init

    singleton_post_init
  end

  # Get gecos field from /etc/passwd, which contains the user's full name.
  def get_gecos
    user = ENV["USER"]
    s = `getent passwd #{user}`
    return s.split(":")[4].split(",")[0]
  end

  def test_setup
    @entries["editor"] = ENV["EDITOR"]
    account = Account.new
    account["name"] = "Hunter Biden"
    account["email"] = "hbiden@rosemontseneca.com"
    accounts = Accounts.new
    accounts["default"] = account
    @entries["accounts"] = accounts
  end

  def [](s : Symbol) : ConfigEntry
    @entries[s.to_s]
  end

end

@@config = Config.new
puts @@config.get_gecos
@@config.test_setup

editor = @@config[:editor]
puts "editor = #{editor}"
accounts = @@config[:accounts].as(Config::Accounts)
hunter = accounts["default"]
puts "hunter = #{hunter.inspect}"
end
