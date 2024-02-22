# Searching Your Mail

Sup supports the following kind of searches:

* [In buffer]({{< relref "#Buffer" >}}) (i.e. the text as displayed on your screen, rather than the underlying message)
* [Quick label]({{< relref "#By Label" >}})
* [Full (general)]({{< relref "#By Content" >}})

## Buffer

Simply press the forward slash key (<kbd>/</kbd>) and type your text. This behavior similar to `vim` and other console apps you're already used to. Remember that this only searches the text *as displayed on screen*, so it's great for partial subject lines and summaries, but for email searches, you're probably more interested in the other options.

## By Label

Press <kbd>l</kbd> to do a quick label search. You will then be prompted for a label; hit <kbd>enter</kbd> to bring up scrollable list of all the labels you've ever used, along with some special labels (Draft, Starred,
Sent, Spam, etc.). 

Highlight a label and press <kbd>enter</kbd> to view all the messages with that label.

## By Content

For a general search, press <kbd>\\</kbd> (that's backslash, following console conventions). Now type in your query. You can just type in arbitrary text, which will be matched on a per-word basis against the bodies of all email in the index, or you can search against [specific fields](##Field search) of your emails as described below. 

Searches containing multiple words are treated as an "OR" search. If you want to search for a specific phrase, enclose it in double quotes. In other words: `three contiguous words` would be treated as `three OR contiguous OR words` any message containing any of those items, where `"three contiguous words"` would be treated as searching for that exact phrase.

## Field Search

Specific message fields can be searched by using <field name\>:<query\>, e.g.: `label:ruby-talk`, or `from:matz@ruby-lang.org`. (Fields include: `body`, `from`, `to`, `subject`, `label`, and others.)

### Attachments
Search for all emails with attachments using `has:attachment` (mails with attachments automatically get labelled with the label `attachment` when indexed). Specific filetypes can be searched for using `has:attachment filetype:pdf`. You can also specify filenames using `filename:somefile.txt`.

Spaces in filenames require parentheses around the filename: `filename:(some file with spaces.txt)`.

### Wildcards
Wildcards are allowed in most searches, but they must be escaped by backslash, i.e.: `subject:\*viagra\*`, `from:william\*`

### Negation
Force non-occurrence (negation) by `-`, e.g.: `-body:"hot soup"`.

### Advanced date queries
If you have the `chronic` gem installed, you can do date queries like `before:today`, `on:today`, `after:yesterday`, `after:(2 days ago)`, `during:february`, and so forth. Note that parentheses are required
for multi-word descriptions.

### Combinations & Labels
You can combine those all together. For example: `label:ruby-talk subject:[ANN] -rails on:today`

By default, query terms are combined with AND, i.e. all conditions must be true. The example above is equivalent to: `label:ruby-talk AND subject:[ANN] AND -rails AND on:today`

Exception: Query terms within the same field type are combined as OR. `subject:apples subject:oranges` will find apples as well as oranges, it is equivalent to `subject:apples OR subject:oranges`

You can make this explicit by using conjunctions like "AND", "OR", "NOT".

### Shortcuts and others 
`is:spam` is translated into `label:Spam`, likewise for some other shortcut queries (`in`, `has`). Note that it will be OR'd with other `label:` queries!

`msgid:123456789@example.com` is useful if you have a unique identifier for an email.

### Even more advanced queries
Play around with the search, and see the [Xapian documentation](http://xapian.org/docs/) for details on
more sophisticated queries (date ranges, "within n words", etc.)

For a complete description of all search keywords, check `lib/sup/index.rb`, in particular, search for `PREFIX`.
