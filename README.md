# Csup - a Crystal rewrite of Sup

**This is a work in progress!  It's nowhere close to finished!  You have been warned!**

I have been a user of the Sup mail client for around 14 years,
and about five years ago I switched to using (and enhancing) a fork of Sup
that uses [notmuch](https://notmuchmail.org/) as its backend for storing, searching,
and tagging email.  You can find my version of this Sup variant, which I call
Sup-notmuch, [here](https://www.bloovis.com/cgit/sup-notmuch/).

For a while now I've been toying with the idea of rewriting
Sup-notmuch in [Crystal](https://crystal-lang.org/), a compiled language inspired by Ruby.  There
is no good reason for going to all this trouble: Sup already works
very well and is fast enough despite being written in Ruby.  The Crystal
version will be simpler to deploy than Sup, being a single compiled binary.
Its memory usage will be greatly reduced (experiments show a 50 MB reduction),
and its performance should be better.  But the main reason for doing this is that I thought
it would be an interesting exercise and a good learning experience.

Sup is filled with Ruby-isms that exploit all the power of  that
very dynamic and expressive language.  But many of these isms
are not available in Crystal, due to its being a compiled language
that performs type-checking at compile time.  Some of these isms include:

1. the construction of symbols at run time
2. the construction of method names at run time and subsequent calls to those methods
3. methods that take an optional block and can test for the existence of the block
using `block_given?`.
4. parallel processing using threads, requiring frequent use of mutexes

It's possible to simulate and possibly come close to the first three of these isms,
using Crystal macros.  But it's not quite the same thing, and the reimplementations
almost always differ in some respects from the original Ruby versions.

As for the fourth ism, Sup appears to use parallel processing for two purposes:

1. Asynchronously filling in the buffer with more data when the cursor gets
close to the bottom of the buffer.  This was probably implemented because
in the early days when Sup was first written, computers (and the Ruby
interpreter) were much slower
and threading probably took a noticeably long time.

2. Polling for new messages in the background.  This was probably implemented
for the same reason as #1.

Crystal supports concurrency using fibers and channels, to implement
cooperative multitasking.  But it does not implement parallel processing.
So in Csup, filling in buffers and polling are done synchronously.
There are commands for performing both actions, as in Sup.  But Csup
will also perform these actions in a synchronous way:

1. In a thread index view, if the user attempts to move the cursor down past
the end of the buffer, Csup will load new threads.

2. In the main command loop, if the user does not type a character after
the number of seconds specified in the `:poll_interval` config option, Csup
will run the poll command.

Experiments on a ThinkPad T450s with an SSD have shown that these
synchronous actions are fast enough to seem nearly instantaneous, so
that the parallel processing of Sup is not missed.
