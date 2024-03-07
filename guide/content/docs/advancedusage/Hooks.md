---
weight: 2
---

# Hooks

Hooks in Csup are very different from hooks in Sup.

In Sup, a hook is a piece of Ruby code that Sup evaluates and executes, with some
variable context, as if this code were part of Sup itself.

In Csup, a hook is an executable program that is entirely separate from Csup.
A hook is typically a shell script, but could be written in any language, Ruby
being another obvious choice.  Hooks live in the directory `~/.csup/hooks`,
and should be marked as executable using `chmod +x`.

In order for Csup hooks to work properly, you must change the default shell
from dash to bash.  Run this command:

    sudo dpkg-reconfigure dash

When you are asked whether you want dash to be the default shell, select "No".

When Csup executes a hook, it passes any required parameters and data as one or more lines to
the hook's standard input.  Csup then reads whatever the hook sends to its standard output,
and uses that as the "value" of the hook.

Here is the list of hooks that Csup currently supports.

## before-poll

Csup calls this hook just before it calls `notmuch new`.  This gives the hook the opportunity
to fetch mail, perhaps using `fetchmail`.  If successful, the hook should return
an exit status of 0; otherwise it should return a non-zero exit status.  If the hook
needs to show the user a message about what it did, it should write this message
as a single line to standard output.

Here is a sample `~/.csup/hooks/before-poll` hook:

```
#!/bin/sh
fetchmail >>/tmp/fetchmail.log
exit 0	# always return 0 because fetchmail returns non-zero if no messages
```

## mime-decode

Csup calls this hook to convert mime-encoded content (typically HTML) to plain text
for displaying in a thread view.
Csup sends the hook a line containing the content type,
followed by the raw content data.
If the hook recognizes the content type as something that could be sensibly
converted to plain text, it should pass the remainder
of the input to the appropriate decoding program, and return
the exit status of the decoding program.
Otherwise the hook should ignore the content, and return a non-zero exit status.

Here is a sample `~/.csup/hooks/mime-decode` hook:

```
#!/bin/sh
read type
case $type in
text/html)
  cat - | w3m -T text/html -dump
  ;;
text/plain)
  cat
  ;;
*)
  exit 1
  ;;
esac
```

## mime-view

Csup calls this hook when the user wants to view mime-encoded content (typically
PDF or image) in an external program.
Csup sends the hook a line containing the content type,
followed by the raw content data.
If the hook recognizes the content type, is should pass the remainder
of the input to the appropriate viewing program, and return
the exit status of the viewing program.
Otherwise the hook should ignore the content, and return a non-zero exit status.


Here is a sample `~/.csup/hooks/mime-view` hook for Linux Mint that uses
`xviewer` to view images, and `xreader` to view PDF files.  Note that it takes special
care to ensure that the temporary file it creates is always
deleted on exit.

```
#!/bin/sh

view () {
  viewer=$1
  t=$(mktemp) || exit 1
  trap "rm -f -- '$t'" EXIT
  cat >$t
  $viewer $t
  status=$?
  rm -f -- "$t"
  trap - EXIT
  exit $status
}

read type
case $type in
*/pdf)
  view xreader
  ;;
image/*)
  view xviewer
  ;;
*)
  exit 1
  ;;
esac
```

## signature

Csup calls this hook, if it exists, to fetch signature lines to append
to sent emails.  If the hook does not exist, Csup will use
the contents of the signature file named in the `signature` part
of the sender's account information in `~/.csup/config.yaml`

Here is a `~/.csup/hooks/signature` hook that outputs a random fortune
to be used as a signature.

```
#!/bin/sh
/usr/games/fortune
```

## forward-attribution

When forwarding or replying to a message, csup mentions the origin of the
message by adding attributions to it.  The default attribution for forwarding
looks like this:

```
--- Begin forwarded message from John Doe ---

     headers and body of the message

--- End forwarded message ---
```

The forward attribution can be customized in the `forward-attribution` hook.
Csup sends the hook a line containing the message's author, followed
by a line containing the message's timestamp (number of seconds since the Epoch).
The hook responds by outputting two lines: the text of the begin line
and the text of the end line.

Here is a sample `~/.csup/hooks/forward-attribution` hook:

```
#!/usr/bin/env ruby
name = STDIN.gets.strip
timestamp = STDIN.gets.strip.to_i
t = Time.at(timestamp)
puts "--- Start of amazing forwarded message from #{name} of #{t.strftime('%B %H, %Y at %H:%M')} ---"
puts "--- End of amazing forwarded message from #{name} of #{t.strftime('%B %H, %Y at %H:%M')} ---"
```

## attribution

The default attribution for replies looks like this:

```
Excerpts from Joe Blogg's message of 1 Jan 1999:
```

The attribution for replies can be customized in the `attribution` hook.
As with the `forward-attribution` hook, 
Csup sends the hook a line containing the message's author, followed
by a line containing the message's timestamp (number of seconds since the Epoch).
The hook responds by outputting the text of the quote line (can be multi-line).

Here is a sample `~/.csup/hooks/attribution` hook:

```
#!/usr/bin/env ruby
name = STDIN.gets.strip
timestamp = STDIN.gets.strip.to_i
t = Time.at(timestamp)
puts "The Great and Powerful #{name} wrote the following on #{t.strftime('%B %H, %Y at %H:%M')}:"
```

## goto

The `g` command in thread view mode looks for a URL in the line under
the cursor, and if it finds one, it sends it to the goto hook.  The hook
reads one line containing the URL, then invokes the appropriate browser
program to view the URL.

Here is a sample `~/.csup/hooks/goto` hook:

```
#!/bin/sh
# The goto hook reads a URL from standard input, then
# runs the appropriate viewer for that URL.
read url
xdg-open "$url"
```
