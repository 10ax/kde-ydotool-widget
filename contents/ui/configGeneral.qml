import QtQuick
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami

// Config page for the "General" group in contents/config/main.xml. The framework
// copies every entry onto this item as a cfg_<name> property, so the control
// write through those rather than touching Plasmoid.configuration directly
// (that would skip Apply/Discard).
Kirigami.FormLayout {
    id: page

    // Not an alias: a ComboBox maps an index to a string value.
    property string cfg_trayIndicator

    QQC2.ComboBox {
        id: indicatorCombo

        Kirigami.FormData.label: i18n("Tray indicator:")

        textRole: "text"
        model: [
            { value: "dot-when-running", text: i18n("Dot while running") },
            { value: "dot-always", text: i18n("Dot always") },
            { value: "icon-swap", text: i18n("Switch the icon with the state") },
            { value: "none", text: i18n("Nothing, tooltip only") }
        ]
        // Bind rather than resolve the index in Component.onCompleted: cfg_
        // may not be populated yet at that point and the combo would be blank.
        currentIndex: Math.max(0, model.findIndex(option => option.value === page.cfg_trayIndicator))
        onActivated: page.cfg_trayIndicator = model[currentIndex].value
    }

    QQC2.Label {
        Kirigami.FormData.isSection: true
        text: i18n("The mouse glyph is identical for both states once the panel recolours it, so the indicator is what tells them apart. The tooltip always reports the state either way.")
        wrapMode: Text.WordWrap
        opacity: 0.7
    }
}
