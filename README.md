# Csup - a Crystal rewrite of the Sup mail client that uses notmuch

This is rewrite in Crystal of the Sup mail client, which I call Csup.
It uses [notmuch](https://notmuchmail.org/)
as the mail store and search engine.  I based this work on an
existing notmuch-enabled variant of Sup, which I call Sup-notmuch.
You can find my version of the Sup-notmuch variant
[here](https://www.bloovis.com/cgit/sup-notmuch/).

As of this writing (2024-03-01), Csup has nearly all of of the
functionality of Sup-notmuch, except for crypto support and a few
lesser-used commands that will be added as needed.

Most of Csup is a port of code from Sup-notmuch, except for the
message threading code, which I rewrote to use notmuch not just for
determining the structure of the message thread trees, but also for
obtaining the headers and content of the messages.  This avoids most
instances where Csup has to read the raw message files.

I also eliminated the parallel processing that Sup-notmuch used to load thread
data in the background, which required many mutexes and a confusing control flow.

Csup has a built-in SMTP client for sending email,
so it does not depend on an external program like `sendmail`
for this purpose.

The result is a mail client that looks and behaves almost identically
to Sup but is a bit faster (in most cases) and uses much less memory.  It is also
easier to deploy, being a single compiled binary.

## Installation and Configuration

See the [Csup Guide](https://www.bloovis.com/csupguide/) for information
on how to set up notmuch and Csup.  Or look in the `guide/content` subdirectory
of the source repository for the source to the guide.
