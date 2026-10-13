#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
package_id="org.tenax.ydotoolmousemover"
package_type="Plasma/Applet"
helper="$script_dir/contents/scripts/ydotool-mouse-moverctl"
icon_theme_dir="$HOME/.local/share/icons/hicolor/scalable/apps"
icon_files=(
    ydotool-mouse-mover-symbolic.svg
    ydotool-mouse-mover-running-symbolic.svg
)

usage() {
    cat <<'USAGE'
Usage: ./dev.sh <command>

Commands:
  doctor       Check local dependencies and ydotool daemon hints.
  install      Install the plasmoid for the current user and reload Plasma Shell.
  upgrade      Upgrade the installed plasmoid and reload Plasma Shell.
  reinstall    Remove, install, and reload Plasma Shell.
  remove       Remove the plasmoid package for the current user.
  reload       Restart Plasma Shell without logging out.
  preview      Open the installed plasmoid in plasmoidviewer.
  status       Print mouse mover runtime status.
  toggle       Toggle mouse movement on/off through the same helper used by QML.
  stop         Stop mouse movement.
  logs         Follow the mouse mover user-unit logs.
  package-info Show kpackagetool6 info for the installed plasmoid.
  validate     Run lightweight syntax/package checks.

Typical loop while editing:
  ./dev.sh upgrade
  ./dev.sh preview

After adding the widget to System Tray settings once, ./dev.sh upgrade reloads
Plasma Shell so QML/metadata changes are visible without logging out.
USAGE
}

have() {
    command -v "$1" >/dev/null 2>&1
}

require_command() {
    if ! have "$1"; then
        printf 'Missing required command: %s\n' "$1" >&2
        exit 127
    fi
}

is_installed() {
    kpackagetool6 --type "$package_type" --show "$package_id" >/dev/null 2>&1
}

reload_plasma() {
    if systemctl --user list-unit-files plasma-plasmashell.service >/dev/null 2>&1; then
        systemctl --user restart plasma-plasmashell.service
        return
    fi

    if have kquitapp6 && have kstart; then
        kquitapp6 plasmashell || true
        kstart plasmashell >/dev/null 2>&1 &
        return
    fi

    printf 'Could not find a supported Plasma Shell reload method.\n' >&2
    exit 1
}

install_package() {
    require_command kpackagetool6
    chmod +x "$helper" "$script_dir/dev.sh"

    if is_installed; then
        kpackagetool6 --type "$package_type" --upgrade "$script_dir"
    else
        kpackagetool6 --type "$package_type" --install "$script_dir"
    fi

    install_icons
}

# Plasmoid.icon is looked up by name through the icon theme, so an icon that
# only lives in the package directory renders as a blank tray entry.
install_icons() {
    mkdir -p "$icon_theme_dir"

    local icon
    for icon in "${icon_files[@]}"; do
        install -m 0644 "$script_dir/contents/icons/$icon" "$icon_theme_dir/$icon"
    done

    if have kbuildsycoca6; then
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    fi
}

remove_icons() {
    local icon
    for icon in "${icon_files[@]}"; do
        rm -f "$icon_theme_dir/$icon"
    done

    if have kbuildsycoca6; then
        kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
    fi
}

remove_package() {
    require_command kpackagetool6

    if is_installed; then
        kpackagetool6 --type "$package_type" --remove "$package_id"
    else
        printf '%s is not installed.\n' "$package_id"
    fi

    remove_icons
}

validate_package() {
    require_command kpackagetool6
    bash -n "$helper"
    bash -n "$script_dir/dev.sh"

    # Settings are optional, but when present check the XML parses and that every
    # page config.qml names actually resolves: a page that does not shows up as an
    # empty settings dialog, which is hard to diagnose from outside.
    if [ -e "$script_dir/contents/config/main.xml" ]; then
        if command -v xmllint >/dev/null 2>&1; then
            xmllint --noout "$script_dir/contents/config/main.xml" \
                && printf 'ok: config/main.xml parses\n' \
                || { printf 'fail: config/main.xml does not parse\n' >&2; exit 1; }
        else
            printf 'skip: xmllint not installed, config/main.xml unchecked\n'
        fi

        local page
        for page in $(sed -n 's/.*source:[[:space:]]*"\([^"]*\)".*/\1/p' "$script_dir/contents/config/config.qml"); do
            if [ -e "$script_dir/contents/ui/$page" ]; then
                printf 'ok: ui/%s\n' "$page"
            else
                printf 'fail: config.qml references missing ui/%s\n' "$page" >&2
                exit 1
            fi
        done
    fi

    kpackagetool6 --type "$package_type" --appstream-metainfo "$script_dir" >/dev/null

    # Plasmoid.icon is resolved by name through the icon theme, so an icon that
    # only lives in the package directory renders as a blank tray entry. Catch a
    # name used in main.qml with no matching file in contents/icons/, which is
    # the mistake that produces "nothing changed in the tray".
    local name
    for name in $(sed -n 's/^[[:space:]]*readonly property string icon[A-Za-z]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$script_dir/contents/ui/main.qml"); do
        if [ -e "$script_dir/contents/icons/$name.svg" ]; then
            printf 'ok: icons/%s.svg (used by main.qml)\n' "$name"
        else
            printf 'fail: main.qml uses the icon "%s" but contents/icons/%s.svg is missing\n' "$name" "$name" >&2
            exit 1
        fi

        if [ -e "$icon_theme_dir/$name.svg" ]; then
            printf 'ok: theme copy %s.svg\n' "$name"
        else
            printf 'warn: %s.svg is not installed in the icon theme yet; run ./dev.sh install\n' "$name"
        fi
    done

    printf 'Validation passed.\n'
}

doctor() {
    require_command kpackagetool6
    printf 'Plasmoid package: %s\n' "$script_dir"
    printf 'Package id: %s\n' "$package_id"

    for command_name in plasmashell plasmoidviewer systemctl systemd-run ydotool; do
        if have "$command_name"; then
            printf 'ok: %s -> %s\n' "$command_name" "$(command -v "$command_name")"
        else
            printf 'missing: %s\n' "$command_name"
        fi
    done

    "$helper" doctor || true
}

case "${1:-}" in
    doctor) doctor ;;
    install)
        install_package
        reload_plasma
        printf 'Installed %s and reloaded Plasma Shell. Add it from System Tray settings if it is not already shown.\n' "$package_id"
        ;;
    upgrade)
        install_package
        reload_plasma
        printf 'Upgraded %s and reloaded Plasma Shell.\n' "$package_id"
        ;;
    reinstall)
        remove_package
        install_package
        reload_plasma
        printf 'Reinstalled %s and reloaded Plasma Shell.\n' "$package_id"
        ;;
    remove)
        "$helper" stop >/dev/null || true
        remove_package
        reload_plasma
        ;;
    reload) reload_plasma ;;
    preview)
        require_command plasmoidviewer
        install_package
        plasmoidviewer --applet "$package_id" --formfactor horizontal --location bottomedge
        ;;
    status) "$helper" status ;;
    toggle) "$helper" toggle ;;
    stop) "$helper" stop ;;
    logs) "$helper" logs ;;
    package-info)
        require_command kpackagetool6
        kpackagetool6 --type "$package_type" --show "$package_id"
        ;;
    validate) validate_package ;;
    -h|--help|help) usage ;;
    *) usage >&2; exit 64 ;;
esac