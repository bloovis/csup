# Crystal rewrite of Sup

**This is a work in progress!  It's nowhere close to finished!  You have been warned!**

I have been a user of the Sup mail client for around 14 years,
and about five years ago I switched to using (and enhancing) a fork of Sup
that uses [notmuch](https://notmuchmail.org/) as its backend for storing, searching,
and tagging email.  You can find my version of this Sup variant, which I call
Sup-notmuch, [here](https://www.bloovis.com/cgit/sup-notmuch/).

For a while now I've been toying with the idea of rewriting
Sup-notmuch in [Crystal](https://crystal-lang.org/), a compiled language inspired by Ruby.  There
is no good reason for going to all this trouble: Sup already works
very well and is fast enough despite being written in Ruby.  It's possible that the Crystal version,
if I could ever get it to work, would be simpler to deploy than Sup,
being a single compiled binary, and its performance would likely be
better.  But the main reason for doing this is that I simply thought
it would be an interesting exercise and a good learning experience.

Sup is filled with Ruby-isms that exploit all the power of  that
very dynamic and expressive language.  But many of these ism
are not available in Crystal, due to its being a compiled language
that performs type-checking at compile time.  Some of these isms include:

1. the construction of symbols at run time
2. the construction of method names at run time and subsequent calls to those methods
3. methods that take an optional block and can test for the existence of the block
using `block_given?`.
3. multi-threaded operation requiring frequent use of mutexes

It's possible to simulate and possibly come close to the first three of these isms,
using Crystal macros.  But it's not quite the same thing and the reimplementations
almost always differ in some respects from the original Ruby versions.

Sup appears to use multiple threads in Sup mainly for
asynchronously filling in buffers with more data when the cursor gets
close to the bottom of the buffer.  I plan to eliminate this feature
entirely, or reimplement itusing Crystal fibers and channels, or reimplement it
using synchronous, single-thread code. I'm not yet sure which direction to go in.
