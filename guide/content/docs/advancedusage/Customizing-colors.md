---
weight: 4
---

# Customizing Colors

The default colors can be overridden by adding entries to
`~/.csup/colors.yaml`. This file does not exist and must be created by the
user.  Only overridden values need to be added to `colors.yaml`, not all of
them.  See the source file `src/colormap.cr` for a complete list of possible colors.

The `colors.yaml` file is compatible with Sup, in that
keys can be symbols (names with a ':' prefix), but ordinary names
(without the ':' prefix) are also allowed.  If this file is missing,
csup uses default values, as defined in in the source file `src/colormap.cr`;
see that file for a complete list of possible colors.

Here is a sample `colors.yaml` that works well with a black-on-pale-yellow
terminal color scheme:

```
:index_new:
  :bg: white
  :fg: default
:index_old: 
  :fg: black
  :bg: default
:index_starred:
  :bg: green
  :fg: white
:date: 
  :fg: black
  :bg: default
:labellist_old: 
  :fg: black
  :bg: default
:labellist_new: 
  :attrs: 
  - bold
  :fg: black
  :bg: white
:size_widget:
  :fg: black
  :bg: default
:tagged:
  :fg: red
  :bg: default
  :attrs:
  - bold
:completion_character:
  :bg: white
  :fg: red
```

## Other Color Schemes

The repository [sup-colors.git](https://github.com/sup-heliotrope/sup-colors)
contain a bunch of user-submitted colorschemes for sup, many of them with screenshots (preferably).

The repository <https://github.com/mklinik/sup-colorscheme-wombat>
contains Markus Klinik's vim wombat-based color scheme:
  ![wombat: index-mode screenshot](https://raw.github.com/mklinik/sup-colorscheme-wombat/master/screenshots/index-view.png)


