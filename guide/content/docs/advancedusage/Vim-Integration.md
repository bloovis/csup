---
weight: 7
---

# Vim Integration

To configure Sup to use VIM (http://www.vim.org/) as editor set _:editor:_ in _~/.sup/config.yaml_ to the ' _vim_ ' command. An example is this command which moves the cursor to the first blank line and tells vim that this is an email:

excerpt from _config.yaml_:

`editor: vim -f -c 'set ft=mail' '+/^\s*\n/' '+nohl'`
