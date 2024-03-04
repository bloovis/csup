---
weight: 8
---

# Emacs Integration

To configure Sup to use Emacs as an editor, set `editor:` in
`~/.csup/config.yaml` to the `emacs` command.  Alternatively, use `emacs
-nw` to run Emacs in text mode.

Excerpt from `~/.csup/config.yaml`:

```yaml
editor: emacs -nw
```

To configure emacs for writing mail, enable message-mode on files
matching the regex `"/sup.*eml$"`.  Add this to your `~/.emacs`:

```elisp
(add-to-list 'auto-mode-alist '("/sup.*eml$" . message-mode))
```

If you want to enable some minor modes for convenience
(e.g. auto-fill-mode, flyspell-mode) use a message-mode hook:

```elisp
(add-hook 'message-mode-hook (lambda ()
  (auto-fill-mode 1)
  (flyspell-mode 1)))
```

To move the cursor down to the first empty line, add to the hook like
this:

```elisp
(add-hook 'message-mode-hook (lambda ()
  (auto-fill-mode 1)
  (flyspell-mode 1)
  (search-forward-regexp "^$")))
```
