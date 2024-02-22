# Configuration Options

Sup will generate a complete configuration file
(\~/.sup/config.yaml) with default settings for all the options the
very first time you run it. If you've been using Sup for a while,
you may be missing some options that have been added since your
config.yaml file was generated.

Some config options that warrant mention. A complete list can be
found in
[sup.rb, circa line 312](https://github.com/sup-heliotrope/sup/blob/develop/lib/sup.rb#L312).(Look
for "def load\_config filename")

Configuring multiple accounts to work intelligently with the Reply
function has its own section: [MultipleAccountsAndReply](MultipleAccountsAndReply)

### Confirm no attachments

    :confirm_no_attachments

If true, and you use words like "attach", "attachment", or
"attached" in your email and don't have any attachments, Sup will
prompt you before sending. This will be true when a default 
config.yaml is generated, but are considered false if not 
explicitly specified. 

### Confirm top posting

    :confirm_top_posting

If true, and you top-post, Sup will tell you that you are a bad
person and will prompt you to confirm that before posting.
This will be true when a default config.yaml is generated,
but are considered false if not explicitly specified. 

### Ask for fields

    :ask_for_cc
    :ask_for_bcc
    :ask_for_subject

These determine which fields you're asked for when composing and
(except for subject) forwarding messages.

### Continuous scrolling

    :continuous_scrolling     

Continuous scrolling is enabled when this is true. 
By default this is false; continuous scrolling can be 
intensive and slow down sup when viewing long threads and lists.

