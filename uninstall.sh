#!/usr/bin/env bash
# Put the stock Pond shell back.
#
#   ./uninstall.sh            move the user copy of pond-shell aside and restart the stock shell
#   ./uninstall.sh --daemon   also stop and remove the librepods daemon
#
# The user copy is renamed to pond-shell.disabled.<time>, not deleted.

set -uo pipefail

fork=${POND_SHELL_FORK:-$HOME/.config/quickshell/pond-shell}

if [ -d "$fork" ]; then
  mv "$fork" "$fork.disabled.$(date +%s)"
  echo "Moved $fork aside."
else
  echo "No user copy at $fork, nothing to move."
fi

# Match the shell by its full command line, so the lock screen (also a qs process) is left alone.
pkill -f '^qs -c pond-shell' 2>/dev/null
sleep 1
setsid qs -c pond-shell -d >/dev/null 2>&1 < /dev/null &
echo "Restarted the stock shell."

if [ "${1:-}" = "--daemon" ]; then
  systemctl --user disable --now librepods.service 2>/dev/null
  rm -f "$HOME/.local/bin/librepods" "$HOME/.local/bin/librepods-ctl" \
        "$HOME/.local/share/systemd/user/librepods.service" \
        "$HOME/.local/share/applications/me.kavishdevar.librepods.desktop" \
        "$HOME/.local/share/icons/hicolor/scalable/apps/librepods.svg"
  rm -rf "$HOME/.local/share/openpods"
  systemctl --user daemon-reload
  echo "Removed the librepods daemon."
fi
