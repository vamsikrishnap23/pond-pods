#!/usr/bin/env bash
# Build and start the librepods daemon, which reads the AirPods and writes their state to a file.
#
#   ./install.sh
#
# It installs under ~/.local and runs as a systemd user service. Nothing under /usr or /etc is written.
# The sidebar widget is a separate step that needs root:  sudo ./install-system.sh

set -euo pipefail

root=$(cd "$(dirname "$0")" && pwd)
deps=(cmake ninja qt6-connectivity qt6-tools qt6-declarative pkgconf libpulse)

missing=()
for p in "${deps[@]}"; do pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p"); done
if ((${#missing[@]})); then
  echo "Missing packages: ${missing[*]}"
  echo "Install them first: sudo pacman -S ${missing[*]}"
  exit 1
fi

cmake -S "$root/daemon" -B "$root/daemon/build" -G Ninja -DBUILD_TESTING=OFF
cmake --build "$root/daemon/build"
cmake --install "$root/daemon/build" --prefix "$HOME/.local"
# The widget replaces the upstream tray app, so keep its launcher entry out of the menu.
rm -f "$HOME/.local/share/applications/me.kavishdevar.librepods.desktop"
systemctl --user daemon-reload
systemctl --user enable librepods.service
# restart rather than start, so an update replaces a daemon that is already running.
systemctl --user restart librepods.service

echo "The librepods daemon is running."
echo "Next, add the widget to the sidebar:  sudo ./install-system.sh"
