---
weight: 2
---

# Ruby 3 Problems

One of the things that motivated me to rewrite Sup-notmuch in Crystal
was the difficulty I had in making Sup-notmuch work on Ruby 3.
Almost everything worked except for the `Notmuch.search` function.
Its signature used to look like this:

    def search(*query, format: 'text', exclude: true, output: 'threads', offset: nil, limit: nil)

The arguments consist of a splat (`*query`) followed by a number of named arguments.
This worked fine in Ruby 2: `*query` became a hash, and the named arguments came
through as expected.

But in Ruby 3, `query` became an array of two hashes.  The first hash (`query[0]`) contained
all of the `*query` arguments, and the second hash (`query[1]`) contained all of the named
arguments.  

I spent many hours trying to figure out which call to `search` was causing the problem.
I put backtrace debugging statements in `search` and other places, but the backtraces
were useless, because they all seemed to stop at `method_missing`.  That's because
Sup is filled with singleton classes, which are implemented with a very clever
hack that channels every class method through `method_missing`.

The other thing
that made the backtraces useless was that many of the calls to `search` came from
lambdas, so the backtraces didn't really show the context where the lambdas had
been created.  Also, it seemed that the way arguments were passed to `search` differed depending
on whether it was called via lambdas or called directly.

I studied the official documentation on how splat args were treated differently in
Ruby 3.  But the documentation was so confusing and mind-numbing that I decided I would
never want to use a language feature that made it impossible to predict with surety
how arguments would be passed in a real program.

After many hours of this frustration, I gave up and wrote a horrible, ugly hack that would make
`search` work with both Ruby 2 and Ruby 3:

```
  def search(*query, **kwargs)
    if query[1]
      kwargs = query[1]
      query[1] = nil
    end
    format = kwargs[:format] || 'text'
    exclude = kwargs[:exclude] || true
    output = kwargs[:output] || 'threads'
    offset = kwargs[:offset] || nil
    limit = kwargs[:limit] || nil
```

I hated this hack so much, despite the fact that it worked, that I
swore that if I rewrote Sup in Crystal, I would regularize the method
signature of `search` so that it would be crystal(hah!)-clear how the
arguments were passed.  This is easy in Crystal due to language
features like types in declarations and compile-time type checking.

Here is the signature of `search` in Csup:

```
  def search(query : String,
             format : String = "text",
             exclude : Bool = true,
             output : String = "threads",
             offset : (Int32 | Nil) = nil,
             limit : (Int32 | Nil) = nil) : Array(String)
```

`query` is now a string, not some vague splat that might be an array or a hash, who knows?
It's also very clear what sort of type the method returns.
