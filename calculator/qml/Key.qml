import QtQuick
import QtQuick.Shapes
import Ambrosia

// One round key. `kind` says which of the three faces it wears: a digit's
// dark gray, a function's lighter gray (delete, AC, %), an operator's
// orange. With the window behind another, all are gray, as a Mac's.
Rectangle {
    id: key

    // What Calc.press takes for it.
    property string name
    property string label
    property string kind: "digit"
    // Drawn instead of a label: "back" (delete) or "sign" (plus over minus).
    property string glyph: ""
    property bool lit: true
    // Set for a moment when its key on the keyboard is pressed.
    property bool flashed: false
    signal pressed()

    readonly property color face: kind === "operator" ? (lit ? Theme.color.palette.orange : "#4e4e4e")
        : kind === "function" ? (lit ? "#5d5b5b" : "#4e4e4e") : "#474545"
    readonly property bool down: area.pressed || flashed

    width: 47
    height: 47
    radius: width / 2
    color: down ? Qt.lighter(face, kind === "operator" ? 1.25 : 1.5) : face
    Behavior on color {
        ColorAnimation { duration: 80 }
    }

    Text {
        visible: key.glyph === ""
        anchors.centerIn: parent
        // The signs sit a little low in the font for a circle.
        anchors.verticalCenterOffset: key.kind === "operator" ? -1.5 : 0
        text: key.label
        color: "white"
        font.family: Theme.uiFont
        font.pixelSize: key.kind === "operator" ? 27 : key.label.length > 1 ? 17 : 21
        font.weight: key.kind === "operator" ? 400 : 500
        renderType: Text.NativeRendering
    }

    Shape {
        visible: key.glyph !== ""
        anchors.centerIn: parent
        width: 24
        height: 24
        preferredRendererType: Shape.CurveRenderer

        // Delete: a tag pointing left with a cross in it.
        ShapePath {
            strokeColor: key.glyph === "back" ? "white" : "transparent"
            strokeWidth: 1.7
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M9.2 5.5h9.3a2.5 2.5 0 0 1 2.5 2.5v8a2.5 2.5 0 0 1-2.5 2.5H9.2a2.5 2.5 0 0 1-1.9-.9L2.6 12l4.7-5.6a2.5 2.5 0 0 1 1.9-.9ZM11.4 9.4l5.2 5.2M16.6 9.4l-5.2 5.2" }
        }
        // The sign: a plus above a slash, a minus below it.
        ShapePath {
            strokeColor: key.glyph === "sign" ? "white" : "transparent"
            strokeWidth: 1.7
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg { path: "M4.2 8.2h6.6M7.5 4.9v6.6M15.8 4.2L8.2 19.8M13.4 16.3h6.6" }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        onClicked: key.pressed()
    }
}
