import QtQuick
import Ambrosia
import Settings

// A push button (Display Settings…, System Report…): its title on a
// capsule of the control color, 24 tall; a sheet's default one (Done) in
// the accent, at least 64 wide.
Rectangle {
    id: button

    property string text
    property bool primary: false
    signal clicked()

    readonly property color face: primary ? Theme.accent.bg : Look.face
    implicitWidth: Math.max(primary ? 64 : 0, label.implicitWidth + 26)
    implicitHeight: Look.popupHeight
    radius: height / 2
    color: tap.pressed ? Qt.darker(face, Theme.dark ? 0.8 : 1.08) : face
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: text
    Keys.onSpacePressed: clicked()

    Label {
        id: label
        anchors.centerIn: parent
        text: button.text
        color: button.primary ? Theme.accent.fg : Theme.color.label.primary
    }
    MouseArea {
        anchors.fill: parent
        id: tap
        onClicked: button.clicked()
    }
}
