#!/usr/bin/env bash
# Stop and remove the librepods daemon.
#
#   ./uninstall.sh
#
# Take the widget out of the sidebar first, with:  sudo ./uninstall-system.sh

set -uo pipefail

systemctl --user disable --now librepods.service 2>/dev/null
rm -f "$HOME/.local/bin/librepods" "$HOME/.local/bin/librepods-ctl" \
      "$HOME/.local/share/systemd/user/librepods.service" \
      "$HOME/.local/share/applications/me.kavishdevar.librepods.desktop" \
      "$HOME/.local/share/icons/hicolor/scalable/apps/librepods.svg"
rm -rf "$HOME/.local/share/openpods"
systemctl --user daemon-reload
echo "Removed the librepods daemon."
