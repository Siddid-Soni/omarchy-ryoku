#!/bin/bash
# Reverse install.sh: remove the symlinks/copies it put in place and restore
# whatever was there before, from the *.bak.<timestamp> backups install.sh
# (or a previous run of this script) left behind.
#
# Safety rules:
#   - Only removes a path if it's a symlink pointing into this repo, or a
#     path install.sh is known to have archived away (the siddid.* plugins,
#     the .siddid.calendar.bak.* orphan). Anything else at these paths is
#     left alone, untouched, with a note printed.
#   - Before overwriting shell.json/keystroke.json, the current copy is
#     itself backed up first — nothing is ever discarded outright.
#   - If more than one backup exists for a path (install.sh run more than
#     once), the newest one is restored.
#   - If no backup exists for a path, the managed symlink/file is simply
#     removed, leaving nothing there.
#
# Usage:
#   ./uninstall.sh

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMARCHY_CONFIG="$HOME/.config/omarchy"
THEMES_DIR="$OMARCHY_CONFIG/themes"
PLUGINS_DIR="$OMARCHY_CONFIG/plugins"
PLUGIN_IDS=(ryoku.bar ryoku.clock ryoku.workspaces ryoku.background)
STAMP=$(date +%s)

newest_backup() {
  # shellcheck disable=SC2012
  ls -1dt "$1".bak.* 2>/dev/null | head -1 || true
}

# Remove a symlink this repo owns (points inside $REPO), then restore the
# newest backup for that path if one exists. Leaves anything not owned by
# this repo untouched.
unlink_and_restore() {
  local target="$1"

  if [[ -L $target ]]; then
    local dest
    dest=$(readlink -f "$target" 2>/dev/null || true)
    if [[ $dest != "$REPO"/* ]]; then
      echo "Skipping $target: symlink points outside this repo, leaving it"
      return
    fi
    rm "$target"
    echo "Removed symlink $target"
  elif [[ -e $target ]]; then
    echo "Skipping $target: not a symlink from this repo, leaving it"
    return
  fi

  restore_backup "$target"
}

# Restore the newest backup for a path that install.sh archived away
# (e.g. the old siddid.* plugin dirs, which aren't symlinks to unlink --
# they were just renamed aside during consolidation).
restore_backup() {
  local target="$1"
  local backup
  backup=$(newest_backup "$target")
  if [[ -n $backup ]]; then
    mv "$backup" "$target"
    echo "Restored $target <- $backup"
  fi
}

echo "Uninstalling Ryoku from $REPO"

# 1. Theme
unlink_and_restore "$THEMES_DIR/ryoku"

# 2. Plugins this repo manages
for id in "${PLUGIN_IDS[@]}"; do
  unlink_and_restore "$PLUGINS_DIR/$id"
done

# 3. Restore whatever install.sh archived during consolidation (only
#    restores if a backup exists; does nothing otherwise).
for stale in siddid.bar siddid.clock siddid.workspaces siddid.background; do
  restore_backup "$PLUGINS_DIR/$stale"
done
restore_backup "$PLUGINS_DIR/.siddid.calendar.bak.20260909194726"
if [[ ! -e $THEMES_DIR/aether ]]; then
  mkdir -p "$THEMES_DIR/aether"
  echo "Recreated empty $THEMES_DIR/aether"
fi

# 4. Config files: back up the current copy first (never discard), then
#    restore the pre-install backup if one exists.
for f in shell.json keystroke.json; do
  target="$OMARCHY_CONFIG/$f"
  [[ -f $target ]] || continue
  cp "$target" "$target.bak.$STAMP"
  echo "Backed up current $target -> $target.bak.$STAMP"
  restore_backup "$target"
done

echo
echo "Not touched: evindor.keystroke (third-party plugin, not managed by this repo)."
echo "Re-applying theme and rescanning plugins..."
command -v omarchy-shell >/dev/null 2>&1 && omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
if command -v omarchy >/dev/null 2>&1 && [[ -d $THEMES_DIR/ryoku ]]; then
  omarchy theme set ryoku 2>/dev/null || echo "note: re-apply your theme manually with: omarchy theme set <name>"
fi

echo "Done."
