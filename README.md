# Csup - a Crystal rewrite of the Sup mail client that uses notmuch

**This is a work in progress!  It's not finished!  You have been warned!**

This is rewrite in Crystal of the Sup mail client, which I call Csup.  It uses notmuch
as the mail store and search engine.  I based this work on an
existing notmuch-enabled variant of Sup, which I call Sup-notmuch.
You can find my version of this Sup variant
[here](https://www.bloovis.com/cgit/sup-notmuch/).

As of this writing (2024-02-05), Csup has basic functionality
for viewing message threads, and composing and replying to emails.
Other features from Sup that have been implemented so far include:

* log mode
* help mode
* saved searches
* user-configured colors, accounts, and contacts
* buffer list mode
* editing labels

Major features yet to be implemented include:

* file browser mode
* completions for prompts
* contact list mode
* label list mode

I rewrote the message threading code to use notmuch not just to determine
the structure of the thread trees, but also to obtain the headers and
content of the messages.
This avoids having to read the raw message files, as Sup does.

I also eliminated the parallel processing that Sup used to load thread
data in the background, which required many mutexes and a confusing control flow.

Csup has a built-in SMTP client for sending email,
so it does not depend on an external program like `sendmail`
for this purpose.

The result is a mail client that looks and behaves almost identically
to Sup but is a bit faster and uses much less memory.  It is also
easier to deploy, being a single compiled binary.

Eventually I'll provide installation and configuration information
for Csup.  Stay tuned!

## Notmuch configuration

Csup works best if you make the following changes to your `.notmuch-config` file:

Add the following line to the `[search]` section:

    exclude_tags=spam;deleted;killed

You can still search for messages with any of these tags by explicitly specifying
the tag in a search: e.g., `tag:deleted` .

Add the following lines to the end of the file:

    [show]
    extra_headers=Delivered-To;X-Original-To;List-Post;Reply-To;References
