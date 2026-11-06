#!/usr/bin/env bash
# Add the AirPods widget to the stock pond-shell: put airpods/ in it and patch its Sidebar.qml.
#
# Run as root. pacman runs this after every pond-shell install or upgrade (see pond-pods.hook),
# because an update restores the stock Sidebar.qml and so removes the patch. Safe to run again.
#
# If this pond-shell's Sidebar.qml does not match what the patch expects, nothing is changed
# and the shell keeps working without the widget.

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
default_target=/usr/share/pond-interface/shell
target=${POND_SHELL_TARGET:-$default_target}

die() { echo "pond-pods: $*" >&2; exit 1; }

if [ "$target" = "$default_target" ] && [ "$(id -u)" -ne 0 ]; then
  die "run this as root: sudo $0"
fi
[ -f "$target/Sidebar.qml" ] || die "$target/Sidebar.qml not found. Is pond-shell installed?"
[ -f "$here/sidebar.patch" ] && [ -d "$here/airpods" ] || die "sidebar.patch or airpods/ missing next to $0"

# Work out the new Sidebar.qml first, so nothing is touched if the patch does not apply.
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
patched=0
if grep -q 'import "airpods" as AirPods' "$target/Sidebar.qml"; then
  patched=1
else
  cp "$target/Sidebar.qml" "$tmp/Sidebar.qml"
  if ! patch -s --no-backup-if-mismatch -p1 -d "$tmp" < "$here/sidebar.patch" >/dev/null 2>&1; then
    die "Sidebar.qml in this pond-shell is not what the patch expects, so the AirPods widget was not added.
pond-pods: The shell is untouched. patches/sidebar.patch needs updating for this pond-shell version."
  fi
fi

# Widget first, so a patched Sidebar.qml never points at a folder that is missing.
rm -rf "$target/airpods"
cp -r "$here/airpods" "$target/airpods"
chmod -R u=rwX,go=rX "$target/airpods"
if [ "$(id -u)" -eq 0 ]; then chown -R root:root "$target/airpods"; fi

if [ "$patched" = 0 ]; then
  cp "$tmp/Sidebar.qml" "$target/Sidebar.qml.pond-pods.new"
  chmod --reference="$target/Sidebar.qml" "$target/Sidebar.qml.pond-pods.new"
  chown --reference="$target/Sidebar.qml" "$target/Sidebar.qml.pond-pods.new"
  mv "$target/Sidebar.qml.pond-pods.new" "$target/Sidebar.qml"
  echo "pond-pods: added the AirPods widget to $target"
else
  echo "pond-pods: refreshed airpods/ in $target (Sidebar.qml was already patched)"
fi
echo "pond-pods: restart the shell to load it:  pkill -f '^qs -c pond-shell'; setsid qs -c pond-shell -d >/dev/null 2>&1 &"
