---
weight: 6
---

# Message Threading

Message threads are the most distinctive feature of Sup and its derivatives,
including Sup-notmuch and Csup.  Other mail systems are capable of showing
messages as threads, but some, like Gmail, flatten the tree structure of the threads,
making it difficult to tell which messages are parents, and which are children.
The Sup family of email clients displays message threads in a visually coherent
manner, using indentation to show the tree hierarchy.

The original Sup used a well-known and documented algorithm to determine thread structure.
Sup-notmuch and Csup, on the other hand, use notmuch to generate the thread trees.
However, Sup-notmuch continued to use Sup's code for parsing and decoding a message into
its constituent parts.  To me, this seemed unnecessary, since notmuch is also capable
of decoding message parts.  Therefore, Csup uses notmuch not only for determining the thread tree structure, but also
for fetching the parts of each message.  It does this in two steps:

1. Use `notmuch search` with a query to generate a list of matching threads.

2. Use `notmuch show --format=json` with the threads obtained in step 1 to get the thread structure
in JSON format.  The JSON provides information about each thread, including its tree structure
and essential information about each message in the thread.  When the user asks
to view a particular message thread, Csup uses the `--body=true` option to include the body
content in the JSON.

## Thread Cache

In order to minimize the amount of thread data obtained from notmuch, Csup keeps
a cache of thread data, indexed by thread ID.  Most queries will attempt to
use any thread data that is already cached.  When it is necessary to forcibly
load thread data into the cache (e.g., when loading message bodies using
`notmuch show --body=true`), Csup will ignore what's in the cache, and overwrite
cache entries with newly loaded data from notmuch.
