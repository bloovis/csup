---
weight: 3
---

# Csup Configuration

Here are the steps you can take to ensure that Csup works properly with
notmuch, and is able to receive, display, and send mail.

## Make bash the default shell

In order for Csup hooks to work properly, you must change the default shell
from dash to bash.  Run this command:

    sudo dpkg-reconfigure dash

When you are asked whether you want dash to be the default shell, select "No".

## Receiving email

If you chose not to use a notmuch hook to fetch mail, you can
create a Csup hook do the same.
See the [before-poll hook]({{< relref "Hooks#before-poll" >}})
for more information.

## Displaying MIME-encoded emails

You can tell Csup how to display MIME-encoded emails through the use of a hook.
See the [mime-decode hook]({{< relref "Hooks#mime-decode" >}})
for more information.

## Viewing MIME-encoded attachments

You can tell Csup how to view MIME-encoded attachments (such as PDFs
and images) through the use of a hook.
See the [mime-view hook]({{< relref "Hooks#mime-view" >}})
for more information.

## Configuration files

Csup expects all of its configuration files to be located in the directory `~/.csup`.
There are two configuration files:

* `config.yaml` (primary configuration file)
* `colors.yaml`  (user interface color scheme)

Additionally, csup will create several more files in the `~/.csup` in
response to user commands:

* `contacts.txt` (contacts list)
* `searches.txt` (saved searches)
* `labels.txt` (user-defined labels)
* `log` (log file)

There is also a `hooks` directory containing optional [hook scripts]({{< relref "Hooks" >}}).

## config.yaml

At startup, Csup reads its configuration information from the file
`~/.csup/config.yaml`.  If this file does not exist, Csup will
create it with default values.  The file is compatible with the Sup
config file, but has some additional information that is
specific to Csup.

The keys in the config file can be symbols (names with a ':' prefix) for Sup compatibility,
or ordinary names (without the ':' prefix).  But when Csup exits,
it saves the config file using ordinary names for keys.

### Notmuch config options

There are two new Notmuch-related configuration options that can
be set in the config file:

* `sent_folder`: a string containing the name of the mail folder to be used to store sent emails.
  If not specified, the default is `sent`.
* `draft_folder`: a string containing the name of the mail folder to be used to store draft emails (i.e., composed but unsent emails)
  If not specified, the default is `draft`.

### Sending email

Because Csup has its own SMTP client for sending email, the
account section in the config file has additional information related
to the SMTP server for that account:

* `smtp_server`: the SMTP server hostname
* `smtp_port`: the port number of the SMTP server
* `smtp_user`: the username to be supplied to the SMTP server (may be different from the
user's email address)
* `smtp_password`: the SMTP user's password

### Confirm no attachments

    :confirm_no_attachments

If true, and you use words like "attach", "attachment", or
"attached" in your email and don't have any attachments, Csup will
prompt you before sending. This will be true when a default 
`config.yaml` is generated, but are considered false if not 
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
intensive and slow down csup when viewing long threads and lists.

### Sample config.yaml

Here is a sample `config.yaml`:

```
---
editor: microemacs
edit_signature: false
ask_for_from: false
ask_for_to: true
ask_for_cc: false
ask_for_bcc: false
ask_for_subject: true
account_selector: true
confirm_no_attachments: true
confirm_top_posting: true
jump_to_open_message: true
default_attachment_save_dir: ""
sent_folder: sent
draft_folder: draft
archive_sent: false
poll_interval: 300
wrap_width: 0
slip_rows: 10
indent_spaces: 2
col_jump: 2
stem_language: english
continuous_scroll: false
crypto: false
hidden_labels: []
mouse: true
  accounts:
    default:
      name: Joe User
      email: joeuser@example.com
      signature: /home/joeuser/.signature
      smtp_server: smtp.example.com
      smtp_port: 587
      smtp_user: joeuser@example.com
      smtp_password: SmTpPaSsWoRd
```

## colors.yaml

At startup, Csup reads the user interface color scheme from the file
`~/.csup/colors.yaml`.  For more information, see
[Customizing Colors]({{< relref "Customizing-Colors" >}}).
