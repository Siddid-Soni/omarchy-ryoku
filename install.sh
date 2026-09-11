#!/bin/bash
# Deploy (or update) the Ryoku desktop: theme + shell plugins + shell.json.
#
# What this does and why:
#
#   - The theme and the four ryoku.* plugins are SYMLINKED into place.
#     Omarchy treats a symlinked theme directory as "the user's own working
#     copy" rather than something cloned from a repo (omarchy-theme-set's
#     theme_came_from_a_repo() checks `[[ ! -L $source && -d $source/.git ]]`),
#     so hyprland.lua and neovim.lua are NOT stripped the way they would be
#     from a git-installed theme. Plugin discovery (omarchy-plugin-catalog)
#     uses `find -L`, so symlinked plugin directories are discovered normally.
#     Net effect: this repo stays the single source of truth, and Omarchy
#     just sees ordinary user config.
#
#   - shell.json and keystroke.json are COPIED, not symlinked. Omarchy
#     commands (`omarchy bar move`, `omarchy plugin enable`, the shell's own
#     mutateShellConfig) rewrite shell.json with an atomic write-then-rename,
#     which would replace a symlink with a plain file and silently detach it
#     from the repo. Use `install.sh --save` to pull config changes back in.
#
# Usage:
#   ./install.sh          deploy this repo's theme/plugins/config
#   ./install.sh --save   copy the live shell.json/keystroke.json back into the repo

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMARCHY_CONFIG="$HOME/.config/omarchy"
THEMES_DIR="$OMARCHY_CONFIG/themes"
PLUGINS_DIR="$OMARCHY_CONFIG/plugins"
PLUGIN_IDS=(ryoku.bar ryoku.clock ryoku.workspaces ryoku.background)
STAMP=$(date +%s)

backup() {
  local target="$1"
  [[ -e $target && ! -L $target ]] || return 0
  mv "$target" "$target.bak.$STAMP"
  echo "Backed up $target -> $target.bak.$STAMP"
}

save() {
  cp "$OMARCHY_CONFIG/shell.json" "$REPO/shell.json"
  echo "Saved shell.json -> $REPO/shell.json"
  if [[ -f $OMARCHY_CONFIG/keystroke.json ]]; then
    cp "$OMARCHY_CONFIG/keystroke.json" "$REPO/keystroke.json"
    echo "Saved keystroke.json -> $REPO/keystroke.json"
  fi
  echo "Review with: git -C \"$REPO\" diff"
}

if [[ ${1:-} == --save ]]; then
  save
  exit 0
fi

echo "Deploying Ryoku from $REPO"

mkdir -p "$THEMES_DIR" "$PLUGINS_DIR"

# 1. Theme
backup "$THEMES_DIR/ryoku"
ln -nsf "$REPO/theme" "$THEMES_DIR/ryoku"
echo "Linked theme -> $THEMES_DIR/ryoku"

# 2. Plugins
for id in "${PLUGIN_IDS[@]}"; do
  backup "$PLUGINS_DIR/$id"
  ln -nsf "$REPO/plugins/$id" "$PLUGINS_DIR/$id"
  echo "Linked plugin -> $PLUGINS_DIR/$id"
done

# 3. Clean up superseded state from the old siddid.*/aether layout. The old
#    pill-styled ryoku.bar (if present) was already backed up above, since it
#    sat at the same path our new symlink just took. Everything here just
#    renamed to .bak.$STAMP, not deleted, so nothing is lost.
#    Only touch things that are plainly the old pieces this repo replaces --
#    never touch anything not named here.
for stale in siddid.bar siddid.clock siddid.workspaces siddid.background; do
  backup "$PLUGINS_DIR/$stale"
done
for orphan in "$PLUGINS_DIR"/.siddid.calendar.bak.*; do
  [[ -e $orphan ]] || continue
  backup "$orphan"
done
if [[ -d $THEMES_DIR/aether && -z $(ls -A "$THEMES_DIR/aether" 2>/dev/null) ]]; then
  rmdir "$THEMES_DIR/aether"
  echo "Removed empty $THEMES_DIR/aether"
fi

# 4. Config files (copied, see header comment)
backup "$OMARCHY_CONFIG/shell.json"
cp "$REPO/shell.json" "$OMARCHY_CONFIG/shell.json"
echo "Installed shell.json"

if [[ -f $REPO/keystroke.json ]]; then
  backup "$OMARCHY_CONFIG/keystroke.json"
  cp "$REPO/keystroke.json" "$OMARCHY_CONFIG/keystroke.json"
  echo "Installed keystroke.json"
fi

# 5. Third-party plugin this config depends on, not vendored here.
if [[ ! -e $PLUGINS_DIR/evindor.keystroke ]]; then
  if command -v omarchy >/dev/null 2>&1; then
    echo "Adding evindor.keystroke..."
    omarchy plugin add https://github.com/evindor/keystroke.git --enable --yes || \
      echo "warning: failed to add evindor.keystroke; add it manually with:" \
           "omarchy plugin add https://github.com/evindor/keystroke.git"
  fi
fi

# 6. Apply
if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
fi
if command -v omarchy >/dev/null 2>&1; then
  omarchy theme set ryoku
fi

echo "Done."
