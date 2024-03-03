---
weight: 4
bookFlatSection: true
title: "New User Guide"
---

# New User Guide

Welcome to CSup! Here's how to get started.

First, try running `csup`. If you have not stored any messages in notmuch,
you'll be
confronted with a mostly blank screen, and a notice at the bottom that
you have no new messages.  If you do have messages in notmuch, you'll
see your inbox with the most recent unarchived messages.

![Inbox mode screenshot](/csupguide/images/inbox-mode.png)

If you want to play around a little at this point, you can press 'b'
to cycle between buffers, ';' to get a list of the open buffers, and
'x' to kill a buffer. There's probably not too much interesting there,
but there's a log buffer with some cryptic messages. You can also
press '?' at any point to get a list of keyboard commands. When you get
bored, press 'q' to quit.

If you're coming from the world of traditional email clients, there are a
some differences you should be aware of at this point. First, Csup
has no folders. Instead, you organize and find messages by a
combination of search and labels (known as "tags" everywhere else in
the world). Search and labels are an integral part of Csup because in
Csup, rather than viewing the contents of a folder, you view the
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

Now let's take a look at your inbox. You'll see that Csup groups
messages together into threads: each line in the inbox is a thread,
and the number in parentheses is the number of messages in that
thread. (If there's no number, there's just one message in the
thread.) In Csup, most operations are on threads, not individual
messages. The idea is that you rarely want to operate on a message
independent of its context. You typically want to view, archive, kill,
or label all the messages in a thread at one time.

Use the up and down arrows to highlight a thread. ('j' and 'k' do the
same thing, and 'J' and 'K' will scroll the whole window. Even the
left and right arrow keys work.) By default, Csup only loads as many
threads as it takes to fill the window; if you'd like to load more,
press 'M' or try to scroll past the bottom of the thread list. You can
hit tab to cycle between only threads with new messages.

Highlight a thread and press Enter to view it. You'll notice that all
messages in the thread are displayed together, laid out graphically by
their relationship to each other (replies are nested under parents).
By default, only the new messages in a thread are expanded, and the
others are hidden. You can toggle an individual message's state by
highlighting a green line and pressing Enter. You can use 'E' to
expand or collapse all messages. You'll also notice that Csup hides quoted text and
signatures. If you highlight a particular hidden chunk, you can press
Enter to expand it, or you can press 'o' to toggle every hidden chunk
in a particular message.

![Thread view screenshot](/csupguide/images/thread-view-mode.png)

Other useful keyboard commands when viewing a thread are: 'n' and 'p'
to jump to the next and previous open messages, 'h' to toggle the
detailed headers for the current message, and Enter to expand or
collapse the current message (when it's on a text region). Enter and
'n' in combination are useful for scanning through a thread---press
Enter to close the current message and jump to the next open one, and
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
search. You'll be prompted for a label; simply hit Enter to bring up
scrollable list of all the labels you've ever used, along with some
special labels (Draft, Starred, Sent, Spam, etc.). Highlight a label
and press Enter to view all the messages with that label.

What you just did was actually a specific search. For a general search,
press '\' or 'F' (forward slash is used for in-buffer search). Now type in your query (again, Ctrl-G to
cancel at any point.) You can just type in arbitrary text, which will be
matched on a per-word basis against the bodies of all email in the
index. Csup supports the older Sup query syntax, which Csup translates into
the equivalent [Notmuch query syntax](https://notmuchmail.org/searching/).
Or you can make use of the Notmuch query syntax directly.

Some of the features of the query syntax:

- Phrasal queries using double-quotes, e.g.: "three contiguous words"
- Queries against a particular field using <field name>:<query>,
  e.g.: label:ruby-talk, or from:matz@ruby-lang.org. (Fields include:
  body, from, to, and subject.)
- Force non-occurrence by -, e.g. -body:"hot soup".
- Date queries like "before:today", "on:today", "after:yesterday", "after:(2 days ago)"
  (parentheses required for multi-word descriptions).

You can combine those all together. For example:

     label:ruby-talk subject:[ANN] -rails on:today

Play around with the search, and see the
[Notmuch documentation](https://notmuchmail.org/searching/)
for details on the underlying query language.

![Search results mode](/csupguide/images/search-results-mode.png)

At this point, you're well on your way to figuring out all the cool
things Csup can do. By repeated application of the '?' key, see if you
can figure out how to:

- List your contacts
- Easily search for all mail from a contact
- Add someone to your contact list

![Contact list mode](/csupguide/images/contact-list-mode.png)

- Postpone a message (i.e., save a draft)
- Quickly re-edit a just-saved draft message
- View the raw header of a message
- Star an individual message, not just a thread
