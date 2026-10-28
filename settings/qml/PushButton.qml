import QtQuick
import Ambrosia
import Settings

// A push button (Display Settings…, System Report…): its title on a
// capsule of the control color, 24 tall.
Rectangle {
    id: button

    property string text
    signal clicked()

    implicitWidth: label.implicitWidth + 26
    implicitHeight: Look.popupHeight
    radius: height / 2
    color: tap.pressed ? Qt.darker(Look.face, Theme.dark ? 0.8 : 1.08) : Look.face
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: text
    Keys.onSpacePressed: clicked()

    Label {
        id: label
        anchors.centerIn: parent
        text: button.text
    }
    TapHandler {
        id: tap
        onTapped: button.clicked()
    }
}
