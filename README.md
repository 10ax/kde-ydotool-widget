# Ydotool Mouse Mover Plasma Widget

KDE Plasma 6 system tray widget that toggles a `ydotool` mouse nudge loop. When enabled, it moves the pointer by 10 pixels once per second. The default direction is right; set `YDTOOL_MOUSE_MOVER_DIRECTION=left|up|down|cycle` before starting if you want a different direction.

The applet is intentionally self-contained under this repository root, outside the normal monorepo layout.

## Requirements

- KDE Plasma 6 (`kpackagetool6`, `plasmoidviewer`, `plasmashell`).
- `ydotool` and its daemon. On Arch this is commonly:

```sh
sudo pacman -S ydotool
sudo systemctl enable --now ydotool.service
```

Depending on local policy, `YDOTOOL_SOCKET` or group permissions may need adjustment. Run `./dev.sh doctor` for quick checks.

## Fast Development Loop

From this directory:

```sh
./dev.sh validate
./dev.sh install
```

Then add **Ydotool Mouse Mover** from the System Tray settings if Plasma does not show it automatically. After it has been added once, iterate with:

```sh
./dev.sh upgrade
```

That upgrades the package and restarts `plasma-plasmashell.service`, so QML and metadata changes are picked up without logging out.

For a standalone preview window:

```sh
./dev.sh preview
```

## Runtime Commands

```sh
./dev.sh status
./dev.sh toggle
./dev.sh stop
./dev.sh logs
```

The applet calls `contents/scripts/ydotool-mouse-moverctl toggle` through Plasma's executable data engine. The helper starts a transient user systemd unit named `ydotool-mouse-mover.service`, so the movement loop is easy to inspect and stop even while Plasma is being reloaded.

## Configuration

Set these variables before toggling the helper or widget:

```sh
export YDTOOL_MOUSE_MOVER_STEP=10
export YDTOOL_MOUSE_MOVER_INTERVAL=1
export YDTOOL_MOUSE_MOVER_DIRECTION=right
```

Supported directions are `right`, `left`, `up`, `down`, and `cycle`.