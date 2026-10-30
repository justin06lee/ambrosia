import QtQuick
import Ambrosia
import Settings

// A push button (Display Settings…, System Report…): its title on a
// rounded face of the control color, 24 tall; a sheet's default one (Done)
// in the accent, at least 64 wide, and as wide as the Cancel beside it.
Rectangle {
    id: button

    property string text
    property bool primary: false
    property real minimumWidth: 0
    signal clicked()

    implicitWidth: Math.max(primary ? 64 : 0, minimumWidth, label.implicitWidth + 26)
    implicitHeight: Look.popupHeight
    radius: Look.pushRadius
    color: primary ? (tap.pressed ? Qt.darker(Theme.accent.bg, Theme.dark ? 0.8 : 1.08) : Theme.accent.bg)
                   : (tap.pressed ? Look.facePressed : Look.face)
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
