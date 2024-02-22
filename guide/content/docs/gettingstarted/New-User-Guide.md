# New User Guide

Welcome to Sup! Here's how to get started.

First, try running `sup`. Since this is your first time, you'll be
confronted with a mostly blank screen, and a notice at the bottom that
you have no new messages. That's because Sup hasn't loaded
anything into its index yet, and has no idea where to look for them
anyways.

If you want to play around a little at this point, you can press 'b'
to cycle between buffers, ';' to get a list of the open buffers, and
'x' to kill a buffer. There's probably not too much interesting there,
but there's a log buffer with some cryptic messages. You can also
press '?' at any point to get a list of keyboard commands, but in the
absence of any email, these will be mostly useless. When you get
bored, press 'q' to quit.

To use Sup for email, we need to load messages into the index. The
index is where Sup stores all message state (e.g. read or unread, any
message labels), and all information necessary for searching and for
threading messages. Sup only knows about messages in its index.

We can add messages to the index by telling Sup about the "source"
where the messages reside. Sources are things like mbox folders, and
maildir directories. Sup doesn't duplicate the actual message content
in the index; it only stores whatever information is necessary for
searching, threading and labelling. So when you search for messages or
view your inbox, Sup talks only to the index (stored locally on
disk). When you view a thread, Sup requests the full content of all
the messages from the source.

The easiest way to set up all your sources is to run `sup-config`.
This will interactively walk you through some basic configuration,
prompt you for all the sources you need, and optionally import
messages from them.  Sup-config uses two other tools, sup-add and
sup-sync, to load messages into the index. In the future you may make
use of these tools directly (see below).

Once you've run sup-config, you're ready to run `sup`. You should see
the most recent unarchived messages appear in your inbox.
Congratulations, you've got Sup working!

If you're coming from the world of traditional MUAs, there are a
couple differences you should be aware of at this point. First, Sup
has no folders. Instead, you organize and find messages by a
combination of search and labels (known as "tags" everywhere else in
the world). Search and labels are an integral part of Sup because in
Sup, rather than viewing the contents of a folder, you view the
results of a search. I mentioned above that your inbox is, by
definition, the set of all messages that aren't archived. This means
that your inbox is nothing more than the result of the search for all
messages with the label "inbox". (It's actually slightly more
complicated---we also omit messages marked as killed, deleted or
spam.)

You could replicate the folder paradigm easily under this scheme, by
giving each message exactly one label and only viewing the results of
simple searches for those labels. But you'd quickly find out that life
can be easier than that if you just trust the search engine, and use
labels judiciously for things that are too hard to find with search.
The idea is that a labeling system that allows arbitrary, user-defined
labels, supplemented by a quick and easy-to-access search mechanism
provides all the functionality that folders does, plus much more, at a
far lower cost to the user.

Now let's take a look at your inbox. You'll see that Sup groups
messages together into threads: each line in the inbox is a thread,
and the number in parentheses is the number of messages in that
thread. (If there's no number, there's just one message in the
thread.) In Sup, most operations are on threads, not individual
messages. The idea is that you rarely want to operate on a message
independent of its context. You typically want to view, archive, kill,
or label all the messages in a thread at one time.

Use the up and down arrows to highlight a thread. ('j' and 'k' do the
same thing, and 'J' and 'K' will scroll the whole window. Even the
left and right arrow keys work.) By default, Sup only loads as many
threads as it takes to fill the window; if you'd like to load more,
press 'M'. You can hit tab to cycle between only threads with new
messages.

Highlight a thread and press enter to view it. You'll notice that all
messages in the thread are displayed together, laid out graphically by
their relationship to each other (replies are nested under parents).
By default, only the new messages in a thread are expanded, and the
others are hidden. You can toggle an individual message's state by
highlighting a green line and pressing enter. You can use 'E' to
expand or collapse all messages or 'N' to expand only the new
messages. You'll also notice that Sup hides quoted text and
signatures. If you highlight a particular hidden chunk, you can press
enter to expand it, or you can press 'o' to toggle every hidden chunk
in a particular message.

Other useful keyboard commands when viewing a thread are: 'n' and 'p'
to jump to the next and previous open messages, 'h' to toggle the
detailed headers for the current message, and enter to expand or
collapse the current message (when it's on a text region). Enter and
'n' in combination are useful for scanning through a thread---press
enter to close the current message and jump to the next open one, and
'n' to keep it open and jump. If the buffer is misaligned with a
message, you can press 'z' to highlight it.

This is a lot to remember, but you can always hit '?' to see the full
list of keyboard commands at any point. There's a lot of useful stuff
in there---once you learn some, try out some of the others!

Now press 'x' to kill the thread view buffer. You should see the inbox
again. If you don't, you can cycle through the buffers by pressing
'b', or you can press ';' to see a list of all buffers and simply
select the inbox.

There are many operations you can perform on threads beyond viewing
them. To archive a thread, press 'a'. The thread will disappear from
your inbox, but will still appear in search results. If someone
replies an archived thread, it will reappear in your inbox. To kill a
thread, press '&'. Killed threads will never come back to your inbox,
even if people reply, but will still be searchable. (This is useful
for those interminable threads that you really have no immediate
interest in, but which seem to pop up on every mailing list.)

If a thread is spam, press 'S'. It will disappear and won't come back.
It won't even appear in search results, unless you explicitly search
for spam.

You can star a thread by pressing '*'. Starred threads are displayed
with a little yellow asterisk next to them, but otherwise have no
special semantics. But you can also search for them easily---we'll see
how in a moment.

To edit the labels for (all the messages in) a thread, press 'l'. Type
in the labels as a sequence of space-separated words. To cancel the
input, press Ctrl-G.

Many of these operations can be applied to a group of threads. Press
't' to tag a thread. Tag a couple, then press '=' to apply the next
command to the set of threads. '=t', of course, will untag all tagged
messages.

Ok, let's try using labels and search. Press 'L' to do a quick label
search. You'll be prompted for a label; simply hit enter to bring up
scrollable list of all the labels you've ever used, along with some
special labels (Draft, Starred, Sent, Spam, etc.). Highlight a label
and press enter to view all the messages with that label.

What you just did was actually a specific search. For a general search,
press '\' (backslash---forward slash is used for in-buffer search,
following console conventions). Now type in your query (again, Ctrl-G to
cancel at any point.) You can just type in arbitrary text, which will be
matched on a per-word basis against the bodies of all email in the
index, or you can make use of the full Xapian query syntax
<http://xapian.org/docs/queryparser.html>:

- Phrasal queries using double-quotes, e.g.: "three contiguous words"
- Queries against a particular field using <field name>:<query>,
  e.g.: label:ruby-talk, or from:matz@ruby-lang.org. (Fields include:
  body, from, to, and subject.)
- Force non-occurrence by -, e.g. -body:"hot soup".
- If you have the chronic gem installed, date queries like
  "before:today", "on:today", "after:yesterday", "after:(2 days ago)"
  (parentheses required for multi-word descriptions).

You can combine those all together. For example:

     label:ruby-talk subject:[ANN] -rails on:today

Play around with the search, and see the Xapian documentation for
details on more sophisticated queries (date ranges, "within n words",
etc.)

At this point, you're well on your way to figuring out all the cool
things Sup can do. By repeated application of the '?' key, see if you
can figure out how to:

- List some recent contacts
- Easily search for all mail from a recent contact
- Easily search for all mail from several recent contacts
- Add someone to your address book
- Postpone a message (i.e., save a draft)
- Quickly re-edit a just-saved draft message
- View the raw header of a message
- Star an individual message, not just a thread

There's one last thing to be aware of when using Sup: how it interacts
with other email programs. As I described above, Sup stores data about
messages in the index, but doesn't duplicate the message contents
themselves. The messages remain on the source. If the index and the
source every fall out of sync, e.g. due to another email client
modifying the source, then Sup will be unable to operate on that
source. For example, for mbox files, Sup stores a byte offset into the
file for each message. If a message deleted from that file by another
client, or even marked as read (yeah, mbox sucks), all succeeding
offsets will be wrong.

That's the bad news. The good news is that Sup is pretty good at being
able to detect this type of situation, and fixing it is just a matter
of running `sup-sync --changed` on the source. Sup will even tell you
how to invoke sup-sync when it detects a problem. This is a
complication you will almost certainly run in to if you use both Sup
and another MUA on the same source, so it's good to be aware of it.

Have fun, and email sup-talk@rubyforge.org if you have any problems!

Appendix A: sup-add and sup-sync
---------------------------------

Instead of using sup-config to add a new source, you can manually run
`sup-add` with a URI pointing to it. The URI should be of the form:

- mbox://path/to/a/filename, for an mbox file on disk.
- maildir://path/to/a/filename, for a maildir directory on disk.

Before you add the source, you need make three decisions. The first is
whether you want Sup to regularly poll this source for new messages.
By default it will, but if this is a source that will never have new
messages, you can specify `--unusual`. Sup polls only "usual" sources
when checking for new mail (unless you manually invoke sup-sync).

The second is whether you want messages from the source to be
automatically archived. An archived message will not show up in your
inbox, but will be found when you search. (Your inbox in Sup is, by
definition, the set of all all non-archived messages). Specify
`--archive` to automatically archive all messages from the source. This
is useful for sources that contain, for example, high-traffic mailing
lists that you don't want polluting your inbox.

The final decision is whether you want any labels automatically
applied to messages from this source. You can use `--labels` to do this.

Now that you've added the source, let's import all the current
messages from it, by running sup-sync with the source URI. You can
specify `--archive` to automatically archive all messages in this
import; typically you'll want to specify this for every source you
import except your actual inbox. You can also specify `--read` to mark
all imported messages as read; the default is to preserve the
read/unread status from the source.

Sup-sync will now load all the messages from the source into the
index. Depending on the size of the source, this may take a while.
Don't panic! It's a one-time process.

Appendix B: Automatically labeling incoming email
-------------------------------------------------

One option is to filter incoming email into different sources with
something like procmail, and have each of these sources auto-apply
labels by using `sup-add --labels`.

But the better option is to learn Ruby and write a before-add hook.
This will allow you to apply labels based on whatever crazy logic you
can come up with. See [Hooks](Hooks) for more.

Appendix C: Reading blogs with Sup
----------------------------------

Really, blog posts should be read like emails are read---you should be
able to mark them as unread, flag them, label them, etc. Use [rss2email]
to transform RSS feeds into emails, direct them all into a source, and
add that source to Sup. Voila!

[rss2email]: http://www.allthingsrss.com/rss2email/
