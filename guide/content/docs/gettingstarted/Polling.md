---
weight: 8
bookFlatSection: true
title: "Polling"
---

# Polling

Csup polls for new messages differently from how Sup polls.

Sup polls for new message in a background thread, i.e. asynchronously
to the main thread that awaits user commands.

Csup does not poll asynchronously.  It polls in two situations:

* If the user doesn't type a key at the main command prompt for
a given number of seconds.  The default number of seconds is 300
(i.e., five minutes), but you can change this by setting the
`poll_interval` value in `~/.csup/config.yaml`, for example:

```
poll_interval: 300
```

* If the user presses the 'P' key (upper case P) at the main command
prompt.

When Csup polls, it first calls the user's
[before-poll hook]({{< relref "Hooks#before-poll" >}}).  This hook
can fetch mail using `fetchmail` or any other mail retrieval program.
The mail must be stored in a maildir visible to notmuch.

After Csup calls the `before-poll` hook, it runs `notmuch new` to tell
notmuch to read and index any new messages.

Finally, Csup will tell all open thread index modes to incorporate any relevant
new threads.

## Loading new threads

By default, thread index modes in Csup load only enough threads to fill
a screen.  Csup will add more threads to the botton of a thread list
if you attempt to move the cursor past the end of the buffer.

This behavior differs from Sup, which would load new threads asynchronously
as the user moved the cursor to within a half screen of the end of the buffer.
Csup does not load new threads asynchronously.
