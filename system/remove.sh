#!/usr/bin/env bash
# Take the AirPods widget out of the stock pond-shell: undo the Sidebar.qml patch, delete airpods/.
# Run as root. If it cannot undo the patch, reinstalling the package restores the stock file:
#   sudo pacman -S pond-shell

set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
default_target=/usr/share/pond-interface/shell
target=${POND_SHELL_TARGET:-$default_target}

die() { echo "pond-pods: $*" >&2; exit 1; }

if [ "$target" = "$default_target" ] && [ "$(id -u)" -ne 0 ]; then
  die "run this as root: sudo $0"
fi
[ -f "$target/Sidebar.qml" ] || die "$target/Sidebar.qml not found. Is pond-shell installed?"

# Sidebar.qml first, so it never imports a folder that is already gone.
if grep -q 'import "airpods" as AirPods' "$target/Sidebar.qml"; then
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  cp "$target/Sidebar.qml" "$tmp/Sidebar.qml"
  if ! patch -R -s --no-backup-if-mismatch -p1 -d "$tmp" < "$here/sidebar.patch" >/dev/null 2>&1; then
    die "could not undo the patch in $target/Sidebar.qml. Restore it with: sudo pacman -S pond-shell"
  fi
  cp "$tmp/Sidebar.qml" "$target/Sidebar.qml.pond-pods.new"
  chmod --reference="$target/Sidebar.qml" "$target/Sidebar.qml.pond-pods.new"
  chown --reference="$target/Sidebar.qml" "$target/Sidebar.qml.pond-pods.new"
  mv "$target/Sidebar.qml.pond-pods.new" "$target/Sidebar.qml"
  echo "pond-pods: removed the patch from $target/Sidebar.qml"
else
  echo "pond-pods: Sidebar.qml is not patched"
fi
rm -rf "$target/airpods"
echo "pond-pods: removed $target/airpods"
