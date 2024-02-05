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

Major features yet to be implemented include:

* editing labels
* file browser mode
* completions for prompts
* contact list mode
* label list mode

I embarked on this rewrite mainly as learning exercise, but
I also wanted to simplify the way Sup-notmuch creates message threads.
It was using notmuch to determine the parent/child tree structure,
but then it was reading the message files directly to parse
their contents.  This seemed wasteful to me, because notmuch
is able to parse the messages and break them up into their parts.
So in Csup, I use notmuch for determining the message tree
structure, and for obtaining the contents of the various parts.
Csup never has to examine the message files directly.

I chose to simplify some aspects of Sup in this port.  In
particular, Sup uses parallel processing to load buffer data in the
background.  This results in code that uses mutexes and has a very
confusing control flow in some areas.  Crystal supports concurrency using
cooperative multi-tasking, but does not support parallel processing.
So I eliminated all forms of asychronous execution, but a user will
notice very little difference from the way Sup operates.

Csup has a built-in SMTP client for sending email,
so it does not depend on external programs like `sendmail`
for this purpose.

The result is a mail client that looks and behaves almost identically
to Sup but is a bit faster and uses much less memory.  It is also
easier to deploy, being a single compiled binary.

Eventually I'll provide installation and configuration information
for Csup.  Stay tuned!
