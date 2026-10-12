import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

// Config page for the "General" group in contents/config/main.xml.
//
// The root is KCM.SimpleKCM (a Kirigami.ScrollablePage with the standard page
// padding), not a bare Kirigami.FormLayout: without it the form sits flush
// against the top-left of the dialog and long text widens the page past the
// dialog, which clips it. Plasma's own config pages (e.g. Folder View) do the
// same.
//
// The framework copies every entry onto this item as a cfg_<name> property, so
// the controls write through those rather than touching Plasmoid.configuration
// directly (that would skip Apply/Discard).
KCM.SimpleKCM {
    id: page

    // Aliases where a control property maps 1:1 to the entry.
    property alias cfg_stepPixels: stepSpin.value
    property alias cfg_intervalSeconds: intervalSpin.value

    // Not aliases: a ComboBox maps its index to a string value.
    property string cfg_trayIndicator
    property string cfg_direction

    Kirigami.FormLayout {
        QQC2.ComboBox {
            id: indicatorCombo

            Kirigami.FormData.label: i18n("Tray indicator:")

            textRole: "text"
            model: [
                { value: "dot-when-running", text: i18n("Dot while running") },
                { value: "dot-always", text: i18n("Dot always") },
                { value: "icon-swap", text: i18n("Switch the icon with the state") },
                { value: "none", text: i18n("Nothing (tooltip only)") }
            ]
            // Bind rather than resolve the index in Component.onCompleted:
            // cfg_ may not be populated yet at that point and the combo would
            // come up blank.
            currentIndex: Math.max(0, model.findIndex(option => option.value === page.cfg_trayIndicator))
            onActivated: page.cfg_trayIndicator = model[currentIndex].value
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Movement")
        }

        QQC2.ComboBox {
            id: directionCombo

            Kirigami.FormData.label: i18n("Direction:")

            textRole: "text"
            model: [
                { value: "cycle", text: i18n("Cycle (a small square)") },
                { value: "right", text: i18n("Right") },
                { value: "left", text: i18n("Left") },
                { value: "up", text: i18n("Up") },
                { value: "down", text: i18n("Down") }
            ]
            currentIndex: Math.max(0, model.findIndex(option => option.value === page.cfg_direction))
            onActivated: page.cfg_direction = model[currentIndex].value
        }

        QQC2.SpinBox {
            id: stepSpin

            Kirigami.FormData.label: i18n("Jump distance:")

            from: 1
            to: 500
            editable: true
            textFromValue: (value) => i18n("%1 px", value)
            valueFromText: (text) => Number.parseInt(text, 10) || 10
        }

        QQC2.SpinBox {
            id: intervalSpin

            Kirigami.FormData.label: i18n("Interval:")

            from: 1
            to: 3600
            editable: true
            textFromValue: (value) => i18n("%1 s", value)
            valueFromText: (text) => Number.parseInt(text, 10) || 1
        }

        QQC2.Label {
            // A plain form row, not a section: section items are rendered as
            // right-aligned headings (Kirigami FormLayout), which reads wrong for
            // a help line. This lands in the control column, wrapped.
            Layout.fillWidth: true
            text: i18n("Changing these restarts the mover if it is running.")
            wrapMode: Text.WordWrap
            opacity: 0.7
            // Guard against the one-line implicit width widening the page past
            // the dialog, which is what clips long text.
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }
    }
}
