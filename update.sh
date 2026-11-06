#!/usr/bin/env bash
# Keep the user copy of pond-shell in step with the stock shell.
#
# While ~/.config/quickshell/pond-shell exists, Quickshell loads it and ignores
# /usr/share/pond-interface/shell, so a pond-shell update never reaches it. This
# rebuilds the copy from the current stock files, then re-applies the one patch and airpods/.
#
#   ./update.sh --check     say whether the stock shell has changed since the copy was made
#                           (exit 0 up to date, 10 behind)
#   ./update.sh             rebuild the copy if it is behind
#   ./update.sh --force     rebuild it even if it is not
#   ./update.sh --restart   restart the shell afterwards
#
# The old copy is kept as pond-shell.old.<time> (one backup, the previous one is replaced).
# If the patch no longer applies to the new Sidebar.qml, nothing is changed.

set -euo pipefail

root=$(cd "$(dirname "$0")" && pwd)
stock=${POND_SHELL_STOCK:-/usr/share/pond-interface/shell}
fork=${POND_SHELL_FORK:-$HOME/.config/quickshell/pond-shell}
marker=$fork/.pond-pods-base

mode=update force=0 restart=0
for arg in "$@"; do
  case "$arg" in
    --check) mode=check ;;
    --force) force=1 ;;
    --restart) restart=1 ;;
    *) echo "usage: $0 [--check] [--force] [--restart]" >&2; exit 2 ;;
  esac
done

die() { echo "$*" >&2; exit 1; }

[ -d "$stock" ] || die "$stock not found. Is pond-shell installed?"
grep -q 'import "airpods" as AirPods' "$fork/Sidebar.qml" 2>/dev/null \
  || die "No patched copy at $fork. Run ./install.sh --shell-only first."

current=${POND_SHELL_VERSION:-$(pacman -Q pond-shell 2>/dev/null | awk '{print $2}')}
current=${current:-unknown}
base=$(cat "$marker" 2>/dev/null || echo unknown)

# What the stock shell has that the copy does not, apart from the files we own or change on purpose.
drift=$(diff -rq "$stock" "$fork" \
  -x airpods -x Sidebar.qml -x .git -x .gitignore -x __pycache__ -x .pond-pods-base 2>&1 || true)

# Sidebar.qml is the one file we edit, so check that the patch still turns the stock one into ours.
sidebar_same=1
tmp=$(mktemp -d)
cp "$stock/Sidebar.qml" "$tmp/"
if ! patch -s --no-backup-if-mismatch -p1 -d "$tmp" < "$root/patches/sidebar.patch" >/dev/null 2>&1 \
   || ! cmp -s "$tmp/Sidebar.qml" "$fork/Sidebar.qml"; then
  sidebar_same=0
fi
rm -rf "$tmp"

behind=0
if [ -n "$drift" ] || [ "$sidebar_same" = 0 ]; then behind=1; fi

echo "pond-shell installed: $current"
echo "your copy was made from: $base"
if [ "$behind" = 1 ]; then
  echo "The stock shell has changed since your copy was made:"
  [ -n "$drift" ] && echo "$drift" | head -15 | sed 's/^/  /'
  [ "$sidebar_same" = 0 ] && echo "  Sidebar.qml (the file the patch edits)"
elif [ "$base" = unknown ]; then
  echo "No version was recorded for your copy, but the shell files match."
elif [ "$base" != "$current" ]; then
  echo "The version differs but the shell files are the same."
else
  echo "Up to date."
fi

if [ "$mode" = check ]; then
  [ "$behind" = 1 ] && exit 10
  exit 0
fi

if [ "$behind" = 0 ] && [ "$force" = 0 ]; then
  printf '%s\n' "$current" > "$marker"
  echo "Nothing to rebuild."
  exit 0
fi

# Build the new copy beside the old one, and swap only when it is complete.
new=$(mktemp -d "$fork.new.XXXXXX")
trap 'rm -rf "$new"' EXIT
cp -rL "$stock/." "$new/"
if ! patch --no-backup-if-mismatch -p1 -d "$new" < "$root/patches/sidebar.patch" >/dev/null; then
  die "The patch no longer applies: Sidebar.qml changed in this pond-shell version.
Your copy was left as it was. patches/sidebar.patch needs updating first."
fi
cp -r "$root/airpods" "$new/airpods"
# Keep the copy's own git history, so the update shows up as a diff.
[ -d "$fork/.git" ] && cp -a "$fork/.git" "$new/.git"
[ -f "$fork/.gitignore" ] && cp "$fork/.gitignore" "$new/.gitignore"
printf '%s\n' "$current" > "$new/.pond-pods-base"

rm -rf "$fork".old.*
mv "$fork" "$fork.old.$(date +%s)"
mv "$new" "$fork"
echo "Rebuilt $fork from pond-shell $current."
echo "The previous copy is at $fork.old.*"
[ -d "$fork/.git" ] && echo "See what changed with: git -C $fork status"

# The running shell watches the old folder, so it has to be restarted to load the new one.
if [ "$restart" = 1 ]; then
  pkill -f '^qs -c pond-shell' 2>/dev/null || true
  sleep 1
  setsid qs -c pond-shell -d >/dev/null 2>&1 < /dev/null &
  echo "Restarted the shell."
else
  echo "Restart the shell to load it:"
  echo "  pkill -f '^qs -c pond-shell'; setsid qs -c pond-shell -d >/dev/null 2>&1 &"
fi
