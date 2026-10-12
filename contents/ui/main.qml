pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    readonly property string helperPath: decodeURIComponent(String(Qt.resolvedUrl("../scripts/ydotool-mouse-moverctl")).replace(/^file:\/\//, ""))
    property bool moverActive: false
    property string lastMessage: ""
    property string lastStatus: "unknown"

    // Mirrors of the movement settings. The helper clamps these as well; doing it
    // here too keeps the command line sane and the values usable in QML.
    readonly property string direction: {
        const value = Plasmoid.configuration.direction;
        return ["right", "left", "up", "down", "cycle"].indexOf(value) !== -1 ? value : "cycle";
    }
    readonly property int stepPixels: clampInt(Plasmoid.configuration.stepPixels, 1, 500, 10)
    readonly property int intervalSeconds: clampInt(Plasmoid.configuration.intervalSeconds, 1, 3600, 1)

    // Passed to the helper as options; the settings are the source of truth and
    // the helper's environment variables are the fallback for CLI use.
    readonly property string helperOptions: "--step " + root.stepPixels
        + " --interval " + root.intervalSeconds
        + " --direction " + root.direction

    // Flipped in Component.onCompleted so the first evaluation of helperOptions
    // cannot restart a mover that is already running fine.
    property bool ready: false

    function clampInt(value, minimum, maximum, fallback) {
        const parsed = Number.parseInt(value, 10);
        if (!isFinite(parsed)) {
            return fallback;
        }
        return Math.max(minimum, Math.min(maximum, parsed));
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function runHelper(action) {
        executableEngine.connectSource(shellQuote(helperPath) + " " + root.helperOptions + " " + action + " # " + Date.now());
    }

    // The options are baked into the mover's systemd unit at start, so a running
    // mover has to be recreated to pick up a change.
    onHelperOptionsChanged: {
        if (root.ready && root.moverActive) {
            root.runHelper("restart");
        }
    }

    function refreshStatus() {
        runHelper("qstatus");
    }

    function toggleMover() {
        runHelper("qtoggle");
    }

    // Validated on read: the config file is user-editable, so an unknown value
    // must not leave the widget with no state indicator at all.
    readonly property string trayIndicator: {
        const mode = Plasmoid.configuration.trayIndicator;
        return ["dot-when-running", "dot-always", "icon-swap", "none"].indexOf(mode) !== -1
            ? mode
            : "dot-when-running";
    }

    readonly property bool badgeVisible: {
        switch (trayIndicator) {
        case "dot-always":
            return true;
        case "dot-when-running":
            return moverActive;
        default:
            return false;
        }
    }

    // Only "icon-swap" changes the icon. The other modes keep one glyph so the
    // tray stays visually stable and the panel can recolour it.
    Plasmoid.icon: trayIndicator === "icon-swap" && moverActive
        ? "input-mouse"
        : "input-mouse-symbolic"
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    Plasmoid.title: i18n("Ydotool Mouse Mover")

    toolTipMainText: Plasmoid.title
    toolTipSubText: moverActive
        ? i18n("Mouse nudge is running")
        : i18n("Mouse nudge is stopped")

    compactRepresentation: MouseArea {
        id: compactMouseArea

        anchors.fill: parent
        hoverEnabled: true

        onClicked: root.toggleMover()

        Kirigami.Icon {
            id: baseIcon
            anchors.fill: parent
            source: Plasmoid.icon
            active: compactMouseArea.containsMouse
        }

        // Status badge: the mouse glyph is identical for both states once the
        // tray recolours it, so carry the state in a coloured dot instead
        // (green = running, muted = stopped). Whether and when it shows is the
        // "Tray indicator" setting.
        Rectangle {
            id: statusBadge

            readonly property real diameter: Math.max(6, Math.round(Math.min(parent.width, parent.height) * 0.4))

            visible: root.badgeVisible
            width: diameter
            height: diameter
            radius: diameter / 2
            anchors.right: baseIcon.right
            anchors.bottom: baseIcon.bottom

            color: root.moverActive
                ? Kirigami.Theme.positiveTextColor
                : Kirigami.Theme.disabledTextColor
            border.width: Math.max(1, Math.round(diameter * 0.15))
            border.color: Kirigami.Theme.backgroundColor
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 15
        Layout.minimumHeight: Kirigami.Units.gridUnit * 8
        collapseMarginsHint: true

        contentItem: ColumnLayout {
            spacing: Kirigami.Units.largeSpacing

            PlasmaExtras.Heading {
                Layout.fillWidth: true
                level: 3
                text: Plasmoid.title
                elide: Text.ElideRight
            }

            PlasmaExtras.PlaceholderMessage {
                Layout.fillWidth: true
                iconName: Plasmoid.icon
                text: root.moverActive ? i18n("Running") : i18n("Stopped")
                explanation: root.lastMessage || i18n("Click the tray icon to toggle the mouse nudge loop.")
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Button {
                    Layout.fillWidth: true
                    text: root.moverActive ? i18n("Stop") : i18n("Start")
                    icon.name: root.moverActive ? "media-playback-stop-symbolic" : "media-playback-start-symbolic"
                    onClicked: root.toggleMover()
                }

                PlasmaComponents3.Button {
                    icon.name: "view-refresh-symbolic"
                    display: QQC2.AbstractButton.IconOnly
                    QQC2.ToolTip.text: i18n("Refresh status")
                    QQC2.ToolTip.visible: hovered
                    onClicked: root.refreshStatus()
                }
            }
        }
    }

    PlasmaCore.Action {
        id: toggleAction
        text: root.moverActive ? i18n("Stop Mouse Mover") : i18n("Start Mouse Mover")
        icon.name: root.moverActive ? "media-playback-stop-symbolic" : "media-playback-start-symbolic"
        onTriggered: root.toggleMover()
    }

    PlasmaCore.Action {
        id: refreshAction
        text: i18n("Refresh Status")
        icon.name: "view-refresh-symbolic"
        onTriggered: root.refreshStatus()
    }

    Plasmoid.contextualActions: [toggleAction, refreshAction]

    P5Support.DataSource {
        id: executableEngine
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            disconnectSource(sourceName);

            const stdout = String(data.stdout || "").trim();
            const stderr = String(data.stderr || "").trim();
            const output = stdout || stderr;
            // The Plasma executable engine exposes the process exit status under
            // the key "exit code" (with a space), not "exitCode".
            const exitCode = Number(data["exit code"]);
            root.lastMessage = output;

            if (output === "running" || output.indexOf("started") === 0 || exitCode === 0) {
                root.moverActive = true;
                root.lastStatus = "running";
                return;
            }

            if (output === "stopped" || output.indexOf("stopped") === 0 || exitCode === 3) {
                root.moverActive = false;
                root.lastStatus = "stopped";
                return;
            }

            if (sourceName.indexOf(" qstatus") === -1) {
                delayedStatusRefresh.restart();
            }
        }
    }

    Timer {
        id: delayedStatusRefresh
        interval: 500
        repeat: false
        onTriggered: root.refreshStatus()
    }

    Timer {
        interval: 5000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: {
        root.ready = true;
        root.refreshStatus();
    }
}