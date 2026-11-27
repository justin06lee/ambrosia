import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import Ambrosia

// A checkbox in a Settings window (PreferencesWindow.qml), measured from
// macOS 27's Finder Settings: a 16 box with rounded corners (14 for the
// small ones beside a glyph), then its label 8.5 to the right in 13.
// Checked, the box takes the accent color and a white check; in a window
// that isn't in front it is gray with a pale check. It says it was toggled;
// whoever owns the setting sets `checked`.
Item {
    id: control

    property bool checked
    property string text
    property real box: 16
    signal toggled()

    readonly property bool dark: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark
    readonly property QtObject colors: dark ? Theme.darkColors : Theme.lightColors
    readonly property bool front: Window.active

    implicitWidth: box + (text === "" ? 0 : 8.5 + label.implicitWidth)
    implicitHeight: box
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Accessible.role: Accessible.CheckBox
    Accessible.name: text
    Accessible.checkable: true
    Accessible.checked: checked
    Keys.onSpacePressed: toggled()

    Rectangle {
        width: control.box
        height: control.box
        radius: control.box * 0.3
        color: control.checked && control.front ? Theme.accent.bg
             : control.checked ? (control.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.16))
             : control.dark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.07)

        Shape {
            anchors.centerIn: parent
            width: 16
            height: 16
            scale: control.box / 16
            visible: control.checked
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: control.front ? Theme.accent.fg : control.dark ? "#dddddd" : "#ffffff"
                strokeWidth: 1.9
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M4.2 8.4l2.6 2.7 5-6.2" }
            }
        }
    }
    Text {
        id: label
        x: control.box + 8.5
        anchors.verticalCenter: parent.verticalCenter
        text: control.text
        color: control.colors.label.primary
        font.family: Theme.uiFont
        font.pixelSize: 13
        renderType: Text.NativeRendering
    }
    MouseArea { anchors.fill: parent; onClicked: control.toggled() }
}
