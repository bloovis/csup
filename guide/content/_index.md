---
title: Csup User Guide
type: docs
---

# What Is This?

Csup is a terminal-based [email client](https://www.bloovis.com/cgit/csup/) for Linux,
written in [Crystal](https://crystal-lang.org/).  It is a partial port of
[Sup-notmuch](https://www.bloovis.com/cgit/sup-notmuch/), which is in turn
a fork of the original [Sup mail client](https://github.com/sup-heliotrope/sup).
It uses [Notmuch](https://notmuchmail.org/) for mail storage, searching, and tagging.

![Csup screen shot](/csupguide/images/csup-screen-shot.png)

This is the user guide for Csup.
It uses [Hugo](https://gohugo.io/) to generate the web site, which you can find
[here](https://www.bloovis.com/csupguide/).
Much of this guide is based on the [Sup-notmuch Guide](https://www.bloovis.com/supguide/).

There are some important differences between Csup and Sup-notmuch:

* The hook system is very different, and Csup has very few hooks.
* Csup does not have any asynchronous behavior.  For example, it will not load
thread data in the background.
* Crypto support is entirely missing.
* Completions for prompts are missing.

Because I created Csup entirely for my own amusement, I will add missing features
only if I find that I need them.

## What's Here

* [Getting Started and Basic Configuration]({{< relref "gettingstarted" >}})
