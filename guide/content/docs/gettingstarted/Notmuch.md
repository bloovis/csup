---
weight: 1
---

# Notmuch

In this guide, I'll show you how I set up notmuch to work with Csup.

In this example, I use fetchmail to fetch mail from my provider, which then
passes the mail off to notmuch for storing in a maildir.  I have set up notmuch
hooks to run fetchmail when Csup runs `notmuch new`, and to tag the incoming messages based
on the sender.

## Create maildirs

I used `maildirmake` to create `~/mail`, and to create the `sent`, `draft`, and `inbox` subdirectories
in that directory:

    maildirmake ~/mail
    maildirmake ~/mail/sent
    maildirmake ~/mail/draft
    maildirmake ~/mail/inbox

## Edit notmuch config file

By default, notmuch assumes that your primary maildir is `~/mail`.  In this
example, I use subdirectories ("folders") of that directory for things like the inbox,
sent mail, and draft mail.

Before using notmuch the first time, use this command to create an initial configuration
file:

    notmuch setup

This creates a file `~/.notmuch-config`.  I edited this file as follows:

* *VERY IMPORTANT*: Changed `synchronize_flags` to false.  This prevents notmuch from modifying email filenames,
  which would confuse Csup and cause it to crash when editing draft messages.

* Changed the `tags=unread;inbox;` line to `tags=new;`.  The reason for this will become
  clear later in the discussion about using a `post-new` hook to tag new email.

* Changed the `exclude_tags` line to `exclude_tags=spam;deleted;killed`.  You can
  still search for spam, deleted, or killed emails by explicitly using those
  tags in a search query.

* Add the line `extra_headers=Delivered-To;X-Original-To;List-Post` to the `[show]`
  section.

* Left the `path` value in the `[database]` section unchanged:

Here is a sample `.notmuch-config` file with all comments removed:

    [database]
    path=/home/joeuser/mail
    [user]
    name=Joe User
    primary_email=joeuser@gmail.com
    [new]
    tags=new;
    ignore=
    [search]
    exclude_tags=spam;deleted;killed
    [maildir]
    synchronize_flags=false
    [show]
    extra_headers=Delivered-To;X-Original-To;List-Post

## Create an index

If you already have email stored in `~/mail`, create an initial notmuch index using this command:

    notmuch new

It's best to do this before running Csup, because it may it may take several minutes
if you have thousands of emails.

## fetchmail setup

My `~/.fetchmailrc` looks something like this:

    poll mail.example.com port 995 with proto POP3 user 'me@example.com'
      pass 'mypassword' options ssl
      mda "notmuch insert --folder=inbox"

This setup uses POP3 to download the mails into the `inbox` folder of `~/mail`, and then
deletes the messages from the mail server.  I do this because I have no desire or need to
read email on a device with no keyboard, a tiny screen, and a non-Linux operating system
(i.e., a so-called "smart" phone). However, some users may want to use IMAP (and a tool like offlineimap),
so that the mails stay on the server.

## notmuch hook setup

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
