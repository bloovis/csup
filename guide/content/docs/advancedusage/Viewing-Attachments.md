---
weight: 3
---

# Viewing Attachments

## Security concerns on opening and viewing attachments

Both mime-view and mime-decode takes input from the received e-mail
(controlled by the sender). The relevant parts are the
```content_type``` and ```filename```. It is very important that any
link in your chain of either viewing (opening) an attachment or
decoding (mime-decode) an attachment does not use ```content_type```
or ```filename``` directly in a command (like opening the attachment
with an external application) without making sure it is safe.

Both ```content_type``` and ```filename``` are escaped so that they
should be safe for use within a command. This is done using Rubys
[Shellwords.escape](http://ruby-doc.org/stdlib-2.0.0/libdoc/shellwords/rdoc/Shellwords.html#method-c-shellescape). 

> The resulting string is intended to be used un-quoted. It is therefore important that neither your
> ```.mailcap``` entries (default view action on non OS X systems), nor any of your mime-view or mime-decode
> hooks use ```content_type``` or ```filename``` quoted in a command.

Otherwise you might open Sup up for [remote command injection](http://en.wikipedia.org/wiki/Remote_code_execution).

## Decoding attachments
Here is an example of how to read HTML only emails, using the
`mime-decode.rb` hook:

```rb
    require 'shellwords'
    unless sibling_types.member? "text/plain"
      case content_type
      when "text/html"
        `/usr/bin/w3m -dump -T #{content_type} #{Shellwords.escape filename}`
      end
    end
```

the Shellwords.escape is to prevent any commands to be injected from incoming mail. Be careful that all hooks taking input from mail are written so that no commands can be passed to them.



Here is the documentation for the hook:

    mime-decode
    -----------
    File: ~/.sup/hooks/mime-decode.rb
    Decodes a MIME attachment into text form. The text will be displayed
    directly in Sup. For attachments that you wish to use a separate program
    to view (e.g. images), you should use the mime-view hook instead.

    Variables:
       content_type: the content-type of the attachment
            charset: the charset of the attachment, if applicable
           filename: the filename of the attachment as saved to disk
      sibling_types: if this attachment is part of a multipart MIME attachment,
                     an array of content-types for all attachments. Otherwise,
                     the empty array.
    Return value:
      The decoded text of the attachment, or nil if not decoded.

## Viewing attachments

By default Sup uses run-mailcap to open attachments on Linux and the ```open``` command on [Mac OSX](Mac-OSX). Check this [thread](https://groups.google.com/d/msg/supmua/9wiVLKD9okY/vyk9iDVcX0oJ) on the [mailinglist](https://groups.google.com/forum/#!forum/supmua) for other solutions on how to view attachments and open HTML parts in a browser. Note that some of the solutions in the thread above uses quotes in an insecure way (see top of this page).

The `mime-view.rb` hook can also be used to open attachments in an external viewer using [xdg-utils](http://cgit.freedesktop.org/xdg/xdg-utils/) in a way like [this (on linux)](https://github.com/gauteh/my-sup-hooks/blob/master/mime-view.rb):
```rb
# filename has already been shellesacped
pid = Process.spawn("xdg-open", filename,
                    :out => '/dev/null',
                    :err => '/dev/null')

Process.detach pid

true
```
