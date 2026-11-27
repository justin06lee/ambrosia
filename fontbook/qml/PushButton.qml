import QtQuick
import Ambrosia

// A push button as macOS 26 draws one (design/tokens.ts, controls.push):
// its title on a rounded face 24 tall; the default one in the accent color
// and at least 64 wide.
Rectangle {
    id: button

    property string text
    property bool primary: false
    signal clicked()

    implicitWidth: Math.max(primary ? 64 : 0, label.implicitWidth + 26)
    implicitHeight: 24
    radius: 7
    color: primary ? (tap.pressed ? Qt.darker(Theme.accent.bg, Theme.dark ? 0.8 : 1.08) : Theme.accent.bg)
                   : (tap.pressed ? (Theme.dark ? "#26ffffff" : "#d3d3d3") : (Theme.dark ? "#13ffffff" : "#e4e4e4"))
    opacity: enabled ? 1 : 0.45
    Accessible.role: Accessible.Button
    Accessible.name: text

    Label {
        id: label
        anchors.centerIn: parent
        text: button.text
        color: button.primary ? Theme.accent.fg : Theme.color.label.primary
    }
    MouseArea {
        id: tap
        anchors.fill: parent
        onClicked: button.clicked()
    }
}
