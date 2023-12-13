require "../lib/email/src/email"

hostname = `hostname`.chomp
now = Time.local
message_id = "<#{now.to_unix}-sup-#{rand 10000}@#{hostname}>"
in_reply_to = "<#{now.to_unix-1000}-#{rand 10000}@gmail.gmail.com>"
date_rfc2822 = "<#{Time::Format::RFC_2822.format(now)}>"

# Create email message
email = EMail::Message.new
email.from    "your_addr@example.com"
email.to      "to@example.com"
email.subject "Subject of the mail"
email.message_id(message_id)
email.date(now)
email.custom_header("In-reply-to", in_reply_to)
#email.custom_header("Date", date_rfc2822)
email.message <<-EOM
Message body of the mail.

--
Your Signature
EOM

email.to_s(STDOUT)
