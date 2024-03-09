# Csup - a Crystal rewrite of the Sup mail client that uses notmuch

This is rewrite in [Crystal](https://crystal-lang.org/)
of the [Sup mail client](https://github.com/sup-heliotrope/sup).
I call it by the unoriginal and unpronounceable name Csup.
It uses [notmuch](https://notmuchmail.org/)
as the mail store and search engine.  I based this work on Ju Wu's
notmuch-enabled variant of Sup, which I call Sup-notmuch.
You can find my fork of this Sup-notmuch variant
[here](https://www.bloovis.com/cgit/sup-notmuch/).

As of this writing (2024-03-09), Csup has nearly all of of the
functionality of Sup-notmuch, but is missing:

* GPG crypto support
* most of Sup's hooks
* a few lesser-used commands (such as "kill") that will be added as needed

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

## Pre-build Configuration

See the [Csup Guide](https://www.bloovis.com/csupguide/) for information
on how to set up notmuch and Csup.  Or look in the `guide/content` subdirectory
of the source repository for the source to the guide.

## Build

To build Csup, type:

    make

To build the guide, type:

    make guidesetup
    make guide

To view the guide on your local machine, type:

    make guideview

Then point your browser to the URL printed by the above command,
typically something like <http://localhost:1313/csupguide/> .

## Acknowledgements

Csup is built on the work of other, smarter people, including (but not limited) to the following:

* William Morgan and the Sup developers
* Carl Worth and the notmuch developers
* Jun Wu for the original notmuch-enabled Sup
* arcage for the Crystal email shard
* Samual Black and Joakim Reinert for the Crystal ncurses shard
* The creators of the beautiful Crystal programming language
