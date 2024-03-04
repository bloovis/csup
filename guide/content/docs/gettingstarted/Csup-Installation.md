---
weight: 2
---

# Csup installation

Note that I have only tested building Csup on Ubuntu 22.04 and Linux Mint 21.
It may work on other distros, but I have not tried them.

Install the Crystal language according to [these instructions](https://crystal-lang.org/install/).

Make sure you have the ncursesw packages installed.  On Debian/Ubuntu do this:

    sudo apt install libncursesw5 libncursesw5-dev

Fetch the source code using:

    git clone https://bionic.bloovis.com/cgit/csup

Change to the csup directory and build it:

    cd csup
    shards install
    make

Copy the binary (`csup`) to some place in your PATH.
