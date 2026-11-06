#!/usr/bin/env bash
# Take the AirPods widget out of the system pond-shell and remove the pacman hook.
#
#   sudo ./uninstall-system.sh
#
# If the patch cannot be undone cleanly, this stops before removing anything else.
# Reinstalling the package restores the stock files:  sudo pacman -S pond-shell

set -euo pipefail

lib=${POND_PODS_LIB:-/usr/local/lib/pond-pods}
hook=${POND_PODS_HOOK:-/etc/pacman.d/hooks/pond-pods.hook}

die() { echo "pond-pods: $*" >&2; exit 1; }

if [ "$lib" = /usr/local/lib/pond-pods ] && [ "$(id -u)" -ne 0 ]; then
  die "run this with sudo: sudo $0"
fi
[ -x "$lib/remove.sh" ] || die "$lib/remove.sh not found, so nothing was installed this way."

"$lib/remove.sh"
rm -f "$hook"
rm -rf "$lib"
echo "pond-pods: removed the widget, the pacman hook and $lib."
echo "pond-pods: restart the shell:  pkill -f '^qs -c pond-shell'; setsid qs -c pond-shell -d >/dev/null 2>&1 &"
