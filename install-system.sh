#!/usr/bin/env bash
# Add the AirPods widget to the system pond-shell, and keep it there across pond-shell updates.
#
#   sudo ./install-system.sh
#
# 1. Copies the tools to /usr/local/lib/pond-pods, owned by root. The pacman hook runs
#    them as root, so it must never run a file from a folder you can write to.
# 2. Installs /etc/pacman.d/hooks/pond-pods.hook, which re-adds the widget after every
#    pond-shell install or upgrade (an update restores the stock Sidebar.qml and removes the patch).
# 3. Adds the widget now.
#
# Nothing here touches the package database. Undo it with: sudo ./uninstall-system.sh

set -euo pipefail

root=$(cd "$(dirname "$0")" && pwd)
lib=${POND_PODS_LIB:-/usr/local/lib/pond-pods}
hook=${POND_PODS_HOOK:-/etc/pacman.d/hooks/pond-pods.hook}

die() { echo "pond-pods: $*" >&2; exit 1; }

# The overrides exist so this can be tested against temporary folders without root.
if [ "$lib" = /usr/local/lib/pond-pods ] && [ "$(id -u)" -ne 0 ]; then
  die "run this with sudo: sudo $0"
fi
own=()
if [ "$(id -u)" -eq 0 ]; then own=(-o root -g root); fi

# Start from a clean shell if an earlier version is installed, so an updated patch is applied fresh.
if [ -x "$lib/remove.sh" ]; then "$lib/remove.sh"; fi

install -d -m 755 "${own[@]}" "$lib"
rm -rf "$lib/airpods"
cp -r "$root/airpods" "$lib/airpods"
chmod -R u=rwX,go=rX "$lib/airpods"
if [ "$(id -u)" -eq 0 ]; then chown -R root:root "$lib/airpods"; fi
install -m 755 "${own[@]}" "$root/system/apply.sh" "$root/system/remove.sh" "$lib/"
install -m 644 "${own[@]}" "$root/patches/sidebar.patch" "$lib/sidebar.patch"

install -d -m 755 "${own[@]}" "$(dirname "$hook")"
if [ -n "${POND_PODS_LIB:-}" ]; then
  # Keep a test run's hook pointing at its own folder, not the real one.
  sed "s#/usr/local/lib/pond-pods#$lib#" "$root/system/pond-pods.hook" > "$hook"
  chmod 644 "$hook"
else
  install -m 644 "${own[@]}" "$root/system/pond-pods.hook" "$hook"
fi

"$lib/apply.sh"
echo "pond-pods: installed. After a pond-shell update pacman re-adds the widget; restart the shell to load it."
