#!/usr/bin/env bash
# Install AirPods for Pond: the librepods daemon, and the airpods/ widget in a user copy of pond-shell.
#
#   ./install.sh                 daemon and shell
#   ./install.sh --daemon-only   build and start the daemon only
#   ./install.sh --shell-only    set up the shell copy only
#
# Nothing under /usr or /etc is written. Undo it with ./uninstall.sh.

set -euo pipefail

root=$(cd "$(dirname "$0")" && pwd)
stock=/usr/share/pond-interface/shell
fork=${POND_SHELL_FORK:-$HOME/.config/quickshell/pond-shell}
deps=(cmake ninja qt6-connectivity qt6-tools qt6-declarative pkgconf libpulse)

want_daemon=1
want_shell=1
case "${1:-}" in
  "") ;;
  --daemon-only) want_shell=0 ;;
  --shell-only) want_daemon=0 ;;
  *) echo "usage: $0 [--daemon-only | --shell-only]" >&2; exit 2 ;;
esac

install_daemon() {
  local missing=()
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
}

install_shell() {
  [ -d "$stock" ] || { echo "$stock not found. Is pond-shell installed?" >&2; exit 1; }

  if [ ! -d "$fork" ]; then
    mkdir -p "$(dirname "$fork")"
    cp -rL "$stock" "$fork"
    patch -p1 -d "$fork" < "$root/patches/sidebar.patch"
  elif grep -q 'import "airpods" as AirPods' "$fork/Sidebar.qml" 2>/dev/null; then
    echo "$fork already has the Sidebar patch, updating airpods/ only."
  else
    echo "$fork already exists and is not patched." >&2
    echo "Apply patches/sidebar.patch to its Sidebar.qml yourself, or move that folder aside and run this again." >&2
    exit 1
  fi

  rm -rf "$fork/airpods"
  cp -r "$root/airpods" "$fork/airpods"
  echo "Installed the widget into $fork"
  echo
  echo "This copy now takes the place of $stock, so pond-shell package updates no longer reach you"
  echo "until you run ./uninstall.sh."
  echo
  echo "To load it, restart the shell (the lock screen is left alone):"
  echo "  pkill -f '^qs -c pond-shell'; setsid qs -c pond-shell -d >/dev/null 2>&1 &"
}

((want_daemon)) && install_daemon
((want_shell)) && install_shell
exit 0
