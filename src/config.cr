require "./singleton"
require "yaml"

module Redwood

class Config
  singleton_class(Config)

  alias Account = Hash(String, String)
  alias Accounts = Hash(String, Account)
  alias ConfigEntry = String | Int32 | Bool | Array(String) | Accounts
  alias ConfigTable = Hash(String, ConfigEntry)

  def initialize
    singleton_pre_init
    @entries = ConfigTable.new

    # Eventually, the code for obtaining config filename should be
    # moved to lib/csup.rb.
    base_dir   = File.join(ENV["HOME"], ".csup")
    @filename = File.join(base_dir, "config.yaml")

    init_config
    debug "config after init_config:\n#{@entries.inspect}"
    singleton_post_init
  end

  # Get gecos field from /etc/passwd, which contains the user's full name.
  def get_gecos : String
    begin
      user = ENV["USER"]
      s = `getent passwd #{user}`
      return s.split(":")[4].split(",")[0]
    rescue
      return "unknown"
    end
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

  def init_config
    # d = default config table
    d = ConfigTable.new
    d["editor"] = ENV["EDITOR"] ||
                 "/usr/bin/vim -f -c 'setlocal spell spelllang=en_us' -c 'set filetype=mail'"
    d["thread_by_subject"] = false
    d["edit_signature"] = false
    d["ask_for_from"] = false
    d["ask_for_to"] = true
    d["ask_for_cc"] = false
    d["ask_for_bcc"] = false
    d["ask_for_subject"] = true
    d["account_selector"] = true
    d["confirm_no_attachments"] = true
    d["confirm_top_posting"] = true
    d["jump_to_open_message"] = false
    d["discard_snippets_from_encrypted_messages"] = false
    d["load_more_threads_when_scrolling"] = true
    d["default_attachment_save_dir"] = ""
    d["sent_folder"] = "sent"
    d["draft_folder"] = "draft"
    d["archive_sent"] = false
    d["poll_interval"] = 300
    d["wrap_width"] = 0
    d["slip_rows"] = 10
    d["indent_spaces"] = 2
    d["col_jump"] = 2
    d["stem_language"] = "english"
    d["sync_back_to_maildir"] = true
    d["continuous_scroll"] = false
    d["always_edit_async"] = false
    d["patchwork"] = true
    d["crypto"] = false
    d["hidden_labels"] = [] of String
    d["show_startup_progress"] = true
    d["split_view"] = false # :vertical or :horizonta
    d["mouse"] = true
    debug "Default config:\n#{d.inspect}"

    if File.exists? @filename
      user_config = load_user_config
      @entries = d.merge(user_config)
    else
      name = get_gecos || ENV["USER"]
      email = ENV["USER"] + "@" + `hostname`.rstrip

      config = ConfigTable.new
      account = Account.new
      account["name"] = name
      account["email"] = email
      account["sendmail"] = "/usr/sbin/sendmail -oem -ti"
      account["signature"] = File.join(ENV["HOME"], ".signature")
      account["gpgkey"] = ""
      accounts = Accounts.new
      accounts["default"] = account
      config["accounts"] = accounts
      @entries = d.merge(config)
      save_config
    end
  end

  def load_user_config : ConfigTable
    puts "load_user_config: filename = #{@filename}"
    yaml = File.open(@filename) { |f| YAML.parse(f) }
    config = ConfigTable.new

    h = yaml.as_h
    h.each do |k, v|
      key = k.as_s.lstrip(':')
      #debug "Key: #{key}"
      if val = v.as_bool?
	config[key] = val
      elsif val = v.as_i?
        config[key] = val
      elsif val = v.as_s?
        config[key] = val
      elsif val = v.as_a?
	a = [] of String
	val.each {|s| a << s.as_s }
	config[key] = a
      elsif key == "accounts"
        h = v.as_h
	accts = Accounts.new
        h.each do |k1, v1|	# for each account
	  key1 = k1.as_s.lstrip(':')	# name of account (default, etc.)
	  val1 = v1.as_h		# hash of values for this account (name, email, etc.)
	  acct = Account.new
	  val1.each do |k2, v2|
	    key2 = k2.as_s
	    val2 = v2.as_s
	    acct[key2] = val2
	  end
	  accts[key1] = acct
	end
	config["accounts"] = accts
      end
    end

    debug "load_user_config: config = \n#{config.inspect}"
    return config
  end

  def save_config
    begin
      File.open(@filename, "w") { |f| @entries.to_yaml(f) }
    rescue
      puts "Unable to save config to #{@filename}!"
    end
  end

end	# Config

end	# Redwood
