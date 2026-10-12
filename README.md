# Ydotool Mouse Mover Plasma Widget

KDE Plasma 6 system tray widget that toggles a `ydotool` mouse nudge loop. When enabled, it moves the pointer by 10 pixels once per second. The direction, jump distance, interval and tray indicator are widget settings — see **Settings** below.

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

## Settings

Right click the tray icon → *Configure Ydotool Mouse Mover…* → **General**.

| Setting | Default | Notes |
|---|---|---|
| Tray indicator | Dot while running | *Dot while running*, *Dot always*, *Switch the icon with the state*, or *Nothing (tooltip only)* |
| Direction | Cycle (a small square) | *Right*, *Left*, *Up*, *Down*, or *Cycle*, which walks a small square and returns to the start |
| Jump distance | 10 px | How far the pointer moves per nudge, 1–500 |
| Interval | 1 s | Seconds between nudges, 1–3600 |

The mouse glyph looks the same in both states once the panel recolours it, so the
indicator is what tells them apart; the tooltip reports the state in every mode.
Changing any movement setting restarts the mover if it is running, because the
helper bakes them into the systemd unit when it starts.

The widget passes these to the helper as options, and the helper clamps them
again, since the config file is editable by hand. They live in
`~/.config/plasma-org.kde.plasma.desktop-appletsrc`, defined by
`contents/config/main.xml`.

## Helper configuration (environment)

Not the same thing as the settings above — these only apply when you run the
helper yourself, and the widget's options take precedence when it calls it:

```sh
export YDTOOL_MOUSE_MOVER_STEP=10
export YDTOOL_MOUSE_MOVER_INTERVAL=1
export YDTOOL_MOUSE_MOVER_DIRECTION=right
```

Supported directions are `right`, `left`, `up`, `down`, and `cycle`.

The same values are accepted as flags, which is what the widget uses:

```sh
./contents/scripts/ydotool-mouse-moverctl --step 12 --interval 2 --direction up toggle
```

`restart` stops and starts the unit so new options take effect on a running mover.