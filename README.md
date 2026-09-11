# omarchy-ryoku

One repo for the whole Ryoku desktop on [Omarchy](https://omarchy.org/): the
`ryoku` theme, the four `ryoku.*` shell plugins, and the shell config that
wires them together.

## Install

```bash
./install.sh
```

This symlinks `theme/` to `~/.config/omarchy/themes/ryoku` and each directory
under `plugins/` to `~/.config/omarchy/plugins/<id>`, copies `shell.json` and
`keystroke.json` into `~/.config/omarchy/`, adds the third-party
[`evindor.keystroke`](https://github.com/evindor/keystroke) plugin this config
depends on if it isn't already installed, then applies the theme. Anything it's
about to overwrite is backed up first (`<path>.bak.<timestamp>`), never deleted
outright.

Safe to re-run any time — it's idempotent.

## Layout

```
theme/                          Ryoku theme: colors, Hyprland/Neovim Lua,
                                 icons, shaders, backgrounds
plugins/
  ryoku.bar/                    Status bar (flat design)
  ryoku.clock/                  Date/time widget + calendar popup
  ryoku.workspaces/             Workspace indicators
  ryoku.background/             Desktop background renderer
shell.json                      Bar layout, enabled plugins, idle timings
keystroke.json                  Config for the vendored evindor.keystroke plugin
install.sh
```

## Why symlinks, and why shell.json is copied instead

Omarchy keeps themes and shell plugins strictly separate — a theme is never
scanned for plugins, and `omarchy theme install` (a git-cloned theme) strips
every `.lua` file, so a cloned Ryoku theme would silently lose
`hyprland.lua` and `neovim.lua`. A **symlinked** theme directory doesn't count
as "installed from a repo" in Omarchy's eyes, though — `omarchy-theme-set`
only applies that stripping when the target both isn't a symlink and has its
own `.git` directory. Because `theme/` here lives in *this* repo's git history,
not as a nested clone at the symlink target, none of that stripping fires and
the Lua ships intact.

Plugin discovery (`omarchy-plugin-catalog`) follows symlinks too, so the four
`plugins/ryoku.*` directories are found exactly like any other user plugin.

`shell.json` and `keystroke.json` are **copied**, not symlinked: Omarchy's own
commands (`omarchy bar move`, `omarchy plugin enable`, drag-reordering in the
bar) rewrite `shell.json` in place with an atomic write, which would replace a
symlink with a plain file and quietly disconnect it from the repo. Pull config
changes made that way back into the repo with:

```bash
./install.sh --save
git status   # review, then commit
```

## Editing plugin code

Files are edited directly in this repo (`plugins/ryoku.*/...`); the symlink
means Omarchy sees the change immediately. The shell's inotify watcher doesn't
always follow through a symlinked directory, so if a change doesn't show up,
force a rescan:

```bash
omarchy-shell shell rescanPlugins
```

## Third-party dependency

`evindor.keystroke` (https://github.com/evindor/keystroke) is not vendored
here — it's someone else's repo. `install.sh` adds it via
`omarchy plugin add` if it's missing. Its settings file, `keystroke.json`, is
ours and is versioned in this repo.
