import QtQuick
import Ambrosia
import Settings

// A checkbox, 16 square with 4 corners, then its label 6 to the right
// (Sound's Mute): checked, the box takes the accent color and a white
// check. It says it was toggled; whoever owns the setting sets `checked`.
Item {
    id: control

    property bool checked
    property string text
    signal toggled()

    implicitWidth: Look.check + 6 + label.implicitWidth
    implicitHeight: Look.check
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checkable: true
    Accessible.checked: checked
    Keys.onSpacePressed: toggled()

    Rectangle {
        width: Look.check
        height: Look.check
        radius: Look.checkRadius
        color: control.checked ? Theme.accent.bg : Look.track
        Behavior on color { ColorAnimation { duration: Theme.fade.fast } }
        Glyph {
            anchors.centerIn: parent
            visible: control.checked
            name: "check"
            size: 14
            color: Theme.accent.fg
        }
    }
    Label {
        id: label
        x: Look.check + 6
        anchors.verticalCenter: parent.verticalCenter
        text: control.text
    }
    MouseArea { anchors.fill: parent; onClicked: control.toggled() }
}
