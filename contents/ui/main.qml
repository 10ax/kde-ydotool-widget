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

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function runHelper(action) {
        executableEngine.connectSource(shellQuote(helperPath) + " " + action + " # " + Date.now());
    }

    function refreshStatus() {
        runHelper("qstatus");
    }

    function toggleMover() {
        runHelper("qtoggle");
    }

    Plasmoid.icon: moverActive ? "input-mouse" : "input-mouse-symbolic"
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

        QQC2.ToolTip.visible: containsMouse
        QQC2.ToolTip.text: root.toolTipSubText
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

        onClicked: root.toggleMover()

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: compactMouseArea.containsMouse
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
            const exitCode = Number(data.exitCode);
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

    Component.onCompleted: root.refreshStatus()
}