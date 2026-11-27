import QtQuick
import Ambrosia
import Notes

// A button in a toolbar capsule: a glyph, lit under the pointer's press;
// gray in a window that isn't in front, grayer when it can do nothing.
Item {
    id: button

    required property Window window
    property string glyph
    property real glyphSize: 19
    property bool usable: true
    readonly property bool pressed: area.pressed && usable
    signal clicked()

    width: Look.control
    height: Look.control

    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 6
        height: 28
        radius: height / 2
        color: Look.pressed
        visible: button.pressed
    }
    Glyph {
        anchors.centerIn: parent
        name: button.glyph
        size: button.glyphSize
        color: !button.usable ? Look.glyphOff : button.window.looksActive ? Look.glyph : Look.glyphInactive
    }
    // Not a TapHandler: a tap would reach what lies under a menu too.
    MouseArea {
        id: area
        anchors.fill: parent
        enabled: button.usable
        onClicked: button.clicked()
    }
}
