---
weight: 1
---

# Notmuch

## Installation

To use sup-notmuch (Sup with notmuch support), you must checkout and use the `notmuch` branch
of the [sup-notmuch git repository](https://www.bloovis.com/cgit/sup-notmuch/).

I have tested sup-notmuch on Linux Mint 19 (based on Ubuntu 18.04),
which uses ruby version 2.5.1p57, and notmuch version 0.26.

To clone the repository and switch to the `notmuch` branch:

    git clone https://bionic.bloovis.com/cgit/sup-notmuch
    cd sup-notmuch
    git checkout notmuch

Sup depends on number of gems.  Here is a partial list:

* optimist
* lockfile
* mime-types
* unicode
* ncursesw (see note below)
* highline
* locale
* rmail (*not* rmail-sup!)
* activesupport (use version 6.0.2.2 for Mint 19 / Ubuntu 18.04)

The ncursesw gem will likely cause the most trouble.  First of all, it requires
that the following packages be installed with `apt install`:

* libncursesw5
* libncursesw5-dev

Secondly, the ncursesw gem may not work correctly; I ran into this problem on Mint 19.3, not on Mint 19.1.
The problem can be revealed by running the following command:

    ruby -e 'require "ncursesw"'

On Mint 19.3, this produced a fatal error about the symbol `set_menu_win` being undefined.
This is a [known problem](https://github.com/sup-heliotrope/sup/issues/550).  I fixed
this in a hacky sort of way.  First, as root, move to the source directory for
the ncursesw gem (the exact path will likely be different on your system):

    cd /var/lib/gems/2.5.0/gems/ncursesw-1.4.10

Then edit the Makefile and make sure `-lmenuw` (*not* `-lmenu`) is in
the LIBS definition, so that it looks like this:

    LIBS = $(LIBRUBYARG_SHARED) -lmenuw -lformw [...]

Then run make to rebuild the shared library, and copy it to the lib subdirectory:

    make
    cp *.so lib

To run Sup, use this command in the repository's top-level directory:

    ruby -I lib bin/sup

If gems are missing, sup will crash with a warning.

But first you'll want to set up notmuch and Sup for receiving, sending, and indexing your mail

## An example setup

In this example, I use fetchmail to fetch mail from my provider, which then
passes the mail off to notmuch for storing in a maildir.  I have set up notmuch
hooks to run fetchmail when Sup runs `notmuch new`, and to tag the incoming messages based
on the sender.  Finally, I have set up Sup to use `msmtp` to send outgoing mail.

### notmuch initial setup

By default, notmuch assumes that your primary maildir is `~/mail`.  In this
example, I use subdirectories ("folders") of that directory for things like the inbox,
sent mail, and draft mail.

Before using notmuch the first time, use this command to create an initial configuration
file:

    notmuch setup

This creates a file `~/.notmuch-config`.  I edited this file as follows:

* changed the `tags=unread;inbox;` line to `tags=new;`.  The reason for this will become
  clear later in the discussion about using a `post-new` hook to tag new email.

* removed `deleted;spam;` from the `exclude_tags` line.  This allows sup to search
  for deleted or spam emails.

* changed `synchronize_flags` to false.  This prevents notmuch from modifying email filenames,
  which could confuse sup and cause it to crash.

I left the `path` value in the `[database]` section unchanged.  I used `maildirmake`
to create `~/mail`, and to create the `sent`, `draft`, and `inbox` subdirectories
in that directory:

    maildirmake ~/mail
    maildirmake ~/mail/sent
    maildirmake ~/mail/draft
    maildirmake ~/mail/inbox

If you already have email stored in `~/mail`, create an initial notmuch index using this command:

    notmuch new

It's best to do this before running Sup, because it may it may take a long time.
(My `~/mail` directory contained about 100K emails and this step took around 10 minutes on
a ThinkPad X200s.)

### fetchmail setup

My `~/.fetchmailrc` looks something like this:

    poll mail.example.com port 995 with proto POP3 user 'me@example.com' pass 'mypassword' options ssl
      mda "notmuch insert --folder=inbox"

This setup uses POP3 to download the mails into the `inbox` folder of `~/mail`, and then
deletes the messages from the mail server.  I do this because I have no desire or need to
read email on a device with no keyboard, a tiny screen, and a non-Linux operating system
(i.e., a so-called "smart" phone). However, some users may want to use IMAP (and a tool like offlineimap),
so that the mails stay on the server.

### notmuch hook setup

First, I created the directory `~/mail/.notmuch/hooks`.  In that directory,
I created two scripts, `pre-new` and `post-new`, and marked them as
executable using `chmod +x`.

The `pre-new` script looks like this:

    #!/bin/sh
    fetchmail &>>/tmp/fetchmail.log
    exit 0

This script saves all fetchmail output in a log file for debugging purposes.  It also returns
an exit code of 0 in all cases.  This is necessary because fetchmail will return a non-zero exit code
if there is no new mail to fetch, and that will cause notmuch to fail.

Notmuch runs the `pre-new` script before it scans the mail directory for new messages.

The `post-new` script looks like this:

    #!/bin/sh
    # immediately archive all messages from "me"
    #notmuch tag -new -- tag:new and from:me@example.com

    # delete all messages from a spammer:
    #notmuch tag +deleted -- tag:new and from:spam@spam.com

    # tag all messages from various mailing lists
    notmuch tag +geeks -- 'tag:new and to:geeks@lists.example.com'
    notmuch tag +nerds -- 'tag:new and to:nerds@lists.example.com'

    # tag message from specific recipients
    notmuch tag +orange -- 'tag:new and from:potus@whitehouse.gov'
    notmuch tag +mw -- 'tag:new and from:word@m-w.com'

    # retag all "new" messages "inbox" and "unread"
    notmuch tag +inbox +unread -new -- 'tag:new and not folder:sent'

    # retag all "new" sent messages "inbox", but not "unread"
    notmuch tag +inbox -new -- 'tag:new and folder:sent'

This script depends on new messages being tagged with the `new` tag.  As mentioned above,
this was accomplished with the `tags=new;` line in `~/.notmuch-config`.

Notmuch runs the `post-new` script after it has scanned the maildir for new messages.

### Sup setup

To tell Sup to fetch mail before polling for new mail, create the
file `~/.sup/hooks/before-poll.rb` that looks like this:

    if (@last_fetchmail_time || Time.at(0)) < Time.now - 15
      say "Fetching mail..."
      system "notmuch new &>>/tmp/notmuch-new.log"
    end
    @last_fetchmail_time = Time.now

This will prevent fetching of mail more frequently than every 15 seconds.  It also
saves a log of the "notmuch new" invocations for debugging purposes.

To allow Sup to display HTML-encoded emails, create the file `$HOME/.sup/hooks/mime-decode.rb`
that looks like this:

    unless sibling_types.member? "text/plain"
      case content_type
      when "text/html"
        `/usr/bin/w3m -dump -T #{content_type} '#{filename}'`
      end
    end

You can handle other mime types in this hook.

There are two new Notmuch-related configuration options that can
be set in `~/.sup/config.yaml`:

* `:sent_folder`: a string containing the name of the mail folder to be used to store sent emails.
  If not specified, the default is `sent`.
* `:draft_folder`: a string containing the name of the mail folder to be used to store draft emails (i.e., composed but unsent emails)
  If not specified, the default is `draft`.

## Sending email

To send email, you must add an account section to your Sup configuration.
In this example, I am using msmtp, an email delivery
program that is much simpler to set up than sendmail.  Here
is what my account setup looks like in `~/.sup/config.yaml`:

    :accounts:
      :default:
        :name: Mark Alexander
        :email: marka@example.com
        :sendmail: msmtp -a example -t

I then created a `~/.msmtprc` file that tells msmtp how to send mails:

    # Set default values for all following accounts.
    defaults
    tls on
    tls_trust_file /etc/ssl/certs/ca-certificates.crt
    logfile ~/.msmtp.log

    # Example service
    account example
    host smtp.example.com
    port 587
    from marka@example.com
    auth on
    tls_starttls on
    user marka@example.com
    password myemailpassword

### Make bash the default shell

In order for the sup hooks to work properly, you must change the default shell
from dash to bash.  Run this command:

    sudo dpkg-reconfigure dash

When you are asked whether you want dash to be the default shell, select "No".

## Sup User's Guide

I have converted the original Sup Wiki to a static HTML [Sup User's Guide](https://www.bloovis.com/supguide/).
Much of the information there is still relevant to sup-notmuch, but you can
ignore anything related to Xapian or installation of the old sup.
