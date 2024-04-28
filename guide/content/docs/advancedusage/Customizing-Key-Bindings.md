---
weight: 4
---

# Customizing Key Bindings

The default key bindings can be modified by adding entries to
`~/.csup/keymap.yaml`. This file does not exist and must be created by the
user.  Only overridden or new values need to be added to `keymap.yaml`.
Key bindings can only be set for existing commands in the various modes
in Csup; you cannot create new commands.

Here is a sample `colors.yaml` that adds some key bindings for ScrollMode,
and one key binding for the global keymap.

```
ScrollMode:
  page_down:
    - "C-v"
  page_up:
    - "C-z"
  jump_to_start:
    - "M-<"
  jump_to_end:
    - "M->"
global:
  kill_buffer:
    - "C-w"
```
