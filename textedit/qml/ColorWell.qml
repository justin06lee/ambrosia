import QtQuick
import Ambrosia
import TextEditor

// A color well of the format bar: the color in use on a rounded square, and
// the colors to choose from under it when pressed. A highlighter's well
// (`marker`) shows an A on its color, struck through in red when there is
// none.
Rectangle {
    id: well

    property color shown: "white"
    // The color as the document has it: "" for none.
    property string current: ""
    property var colors: []
    property bool marker: false
    readonly property bool none: marker && current === ""
    signal chosen(string color)

    width: Look.control
    height: Look.control
    radius: Look.controlRadius
    color: none ? Look.field : shown
    border.width: none ? 0 : 0.5
    border.color: Theme.dark ? "#30ffffff" : "#30000000"

    Text {
        visible: well.marker
        anchors.centerIn: parent
        text: "A"
        font.family: Theme.uiFont
        font.pixelSize: 12
        font.weight: 500
        color: well.none ? Look.glyph : "#1c1c1c"
        renderType: Text.NativeRendering
    }
    Rectangle {
        visible: well.none
        anchors.centerIn: parent
        width: 20
        height: 1.5
        rotation: -45
        color: "#ff453a"
        antialiasing: true
    }
    MouseArea {
        anchors.fill: parent
        onPressed: popup.visible ? popup.close() : popup.openUnder(well)
    }
    ColorPopup {
        id: popup
        colors: well.colors
        current: well.current
        columns: well.marker ? well.colors.length : 8
        onChosen: (color) => well.chosen(color)
    }
}
