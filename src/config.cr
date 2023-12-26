require "./singleton"

module Redwood

class Config
  singleton_class(Config)

  alias Account = Hash(String, String)
  alias Accounts = Hash(String, Account)

  alias ConfigEntry = String | Int32 | Bool | Array(String) | Accounts

  def initialize
    singleton_pre_init
    @entries = Hash(String, ConfigEntry).new
    singleton_post_init
  end

  # Get gecos field from /etc/passwd, which contains the user's full name.
  def get_gecos
    user = ENV["USER"]
    s = `getent passwd #{user}`
    return s.split(":")[4].split(",")[0]
  end
  singleton_method(Config, get_getcos)

  # Methods for retrieving entries as specific types.
  macro get(name, type)
    def {{name}}(s : Symbol | String) : {{type}}
      @entries[s.to_s].as({{type}})
    end
    singleton_method(Config, {{name}}, s)
  end
    
  get(str, String)
  get(int, Int32)
  get(bool, Bool)
  get(strarray, Array(String))

  # Retrieve the specified account.
  def account(s : Symbol | String) : Account
    accounts = @entries["accounts"].as(Accounts)
    accounts[s.to_s].as(Account)
  end
  singleton_method(Config, account, name)

end	# Config

end	# Redwood
