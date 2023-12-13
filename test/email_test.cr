require "../lib/email/src/email"

def answer(prompt : String) : String
  print prompt + ": "
  (gets || "").chomp
end

hostname = `hostname`.chomp
now = Time.local
message_id = "<#{now.to_unix}-sup-#{rand 10000}@#{hostname}>"
in_reply_to = "<#{now.to_unix-1000}-#{rand 10000}@gmail.gmail.com>"
date_rfc2822 = "<#{Time::Format::RFC_2822.format(now)}>"

from = answer("Enter From: address")
to = answer("Enter To: address")

# Create email message
email = EMail::Message.new
email.from    from
email.to      to
email.subject "Subject of the mail"
email.message_id(message_id)
email.date(now)
#email.custom_header("In-reply-to", in_reply_to)
email.message <<-EOM
Message body of the mail.

--
Your Signature
EOM

email.to_s(STDOUT)

print "\n\n"
mx = answer("Enter smtp server")
port = answer("Enter smtp port").to_i
domain = answer("Enter domain")
user = answer("Enter user name")
password = answer("Enter password")

config = EMail::Client::Config.new(mx, port, helo_domain: domain)
config.use_auth(user, password)
config.use_tls(EMail::Client::TLSMode::SMTPS)
config.use_tls(EMail::Client::TLSMode::STARTTLS)

client = EMail::Client.new(config)
begin
  client.start do
    send(email)
  end
rescue ex
  puts "Exception #{ex}"
end
