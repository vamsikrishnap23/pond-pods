# AirPods for Pond

AirPods battery and controls in the Pond OS sidebar.

- **Sidebar card:** a battery ring for the left pod, the right pod and the case, each with its icon inside and the
  percentage below. The card collapses to a single ring with the sidebar, shows lime while charging and coral at 20%
  or below, and hides itself when no AirPods are connected.
- **Flyout:** click the card to open it beside the sidebar. It has larger rings and the controls the AirPods have:
  - listening mode (Off, Transparency, Adaptive, Noise Cancellation, only the ones the model supports)
  - the adaptive noise level slider
  - Conversation Awareness
  - One-Bud ANC
  - ear detection (pause when one pod is out, when both are out, or never)
- **Pause on removal:** the daemon pauses media when a pod comes out and can resume it when it goes back in.

It is built from Pond's own pieces (`Card`, `PanelBackground`, `Toggle`, `Slider`, the theme colours), so it follows
the active theme.

BlueZ does not report battery for AirPods, so a small daemon talks to them directly. See
[docs/daemon-notes](docs/daemon-notes) for why.

## Requirements

- Pond OS with the stock `pond-shell` (Quickshell) sidebar
- AirPods paired and connected through BlueZ
- Build packages: `cmake ninja qt6-connectivity qt6-tools qt6-declarative pkgconf libpulse`

## Install

```
sudo pacman -S cmake ninja qt6-connectivity qt6-tools qt6-declarative pkgconf libpulse
./install.sh
```

Then restart the shell (the script prints the command). `./install.sh --daemon-only` and `--shell-only` do one half.

### What it changes

Nothing under `/usr` or `/etc`. The script:

1. Builds the daemon and installs it under `~/.local` (`bin/`, the systemd user unit, translations), enables the
   `librepods` user service and starts it. It removes the upstream tray app's launcher entry, since the widget
   replaces it.
2. Copies the stock shell from `/usr/share/pond-interface/shell` to `~/.config/quickshell/pond-shell`, where
   Quickshell prefers it over the system copy, applies [`patches/sidebar.patch`](patches/sidebar.patch) to its
   `Sidebar.qml`, and adds the `airpods/` folder.

The patch is the only edit to a stock file. It adds 21 lines and rewrites 7 so the flyout opens and closes like the
wifi, audio and bluetooth ones.

Because the copy takes the place of the system shell, **`pond-shell` package updates no longer reach you** while it
is installed.

## Restore the stock shell

```
./uninstall.sh            # move the copy aside and restart the stock shell
./uninstall.sh --daemon   # also stop and remove the daemon
```

The copy is renamed to `pond-shell.disabled.<time>`, not deleted. If the shell will not draw, switch to a TTY
(Ctrl+Alt+F3), run the same script, and switch back.

## How it works

```
AirPods --L2CAP/BLE--> librepods daemon --> ~/.local/state/librepods/status.json
                              ^                          |
                       librepods-ctl <-- airpods/State.qml (watches the file, sends commands)
                                                         |
                                            airpods/Widget.qml, Panel.qml
```

The daemon writes its whole state as one JSON line whenever it changes. `State.qml` watches that file, so the widget
runs nothing while idle, and sends commands (`noise:anc`, `ear:one`, `adaptive:50`, ...) through `librepods-ctl`.
Pausing media is done by the daemon itself over MPRIS.

## Models and icons

Icons live in `airpods/assets/models/<model-slug>/`, named after the model the daemon reports
(`AirPods Pro 2` becomes `airpods-pro-2`). To add a model, add a folder with `pod-left.svg`, `pod-right.svg`,
`case.svg` and an `ATTRIBUTION.md`. No code changes are needed. See
[airpods/assets/models/README.md](airpods/assets/models/README.md). A model with no folder shows the AirPods Pro 2
icons. AirPods Max has no pods or case, so it uses Pond's headphone icon.

## Status

Developed and used on one machine: Pond OS with niri, AirPods Pro 2, North theme.

Used and working there: the sidebar card, the flyout, switching listening mode, the ear-detection setting, and
pausing when a pod is removed.

**Not tested:** the collapsed (48px) sidebar, the adaptive noise slider, Conversation Awareness, One-Bud ANC, the
case battery with the lid open, the other Pond themes (the ring colours were picked for a dark theme), any other AirPods model, multiple monitors.

### Known issues

- **Low-battery notifications do not appear.** The daemon sends them with the `omarchy` command, which Pond does not
  have, so it only logs a warning. It would need to use the desktop notification service instead.
- **Pausing failed once** after a Bluetooth link drop and reconnect, and worked after the daemon restarted. The
  daemon's log showed it had not yet matched the AirPods to an audio card at that moment. The cause is not confirmed.
  If it happens, `systemctl --user restart librepods` fixes it.
- **The daemon picks the highest-bitrate Bluetooth profile** (SBC-XQ) and re-applies it on every activation, so the
  audio profile may differ from before.
- **A model with no icon folder** makes Qt log a "Cannot open" warning before it falls back to the default icons.

## Credits and licences

This repository mixes three licences.

| Part | Licence | Origin |
|---|---|---|
| `airpods/` QML (`Model.js`, `State.qml`, `Widget.qml`, `Panel.qml`, `Ring.qml`, `PartIcon.qml`), scripts, patch | MIT, see [LICENSE](LICENSE) | `Model.js` and `State.qml` are adapted from [omarchy-pods](https://github.com/thisisgm/omarchy-pods) by GM (MIT). The rest is new, though the flyout's sections and show/hide rules follow omarchy-pods' `Panel.qml`. |
| `daemon/` | GPL-3.0, see [daemon/LICENSE](daemon/LICENSE) | A modified copy of [librepods](https://github.com/kavishdevar/librepods) by Kavish Devar, as modified in omarchy-pods. Details in [daemon/UPSTREAM.md](daemon/UPSTREAM.md). Reverse-engineering Apple's protocol is his work. |
| `airpods/assets/models/airpods-pro-2/` icons | CC BY 3.0 | Noun Project: pods by 우가 우가, case by Alebaer. See that folder's `ATTRIBUTION.md`. Keep it with the icons. |

The daemon runs as its own process and talks to the QML only through a file and a command, so the GPL part and the
MIT part stay separate.

`docs/daemon-notes` are verified notes on the AirPods and the daemon, carried over from omarchy-pods. They mention
Omarchy where they describe its tools.
