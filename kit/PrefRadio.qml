import QtQuick
import QtQuick.Window
import Ambrosia

// One of a set of choices in a Settings window (PreferencesWindow.qml),
// measured from macOS 27's Preview Settings: a 16 disc, then its label 6.5
// to the right in 13. Chosen, the disc takes the accent color and a white
// dot; in a window that isn't in front it is gray with a pale dot. It says
// it was picked; whoever owns the setting sets `chosen`.
Item {
    id: control

    property bool chosen
    property string text
    signal picked()

    readonly property bool dark: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark
    readonly property QtObject colors: dark ? Theme.darkColors : Theme.lightColors
    readonly property bool front: Window.active

    implicitWidth: 16 + 6.5 + label.implicitWidth
    implicitHeight: 16
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Accessible.role: Accessible.RadioButton
    Accessible.name: text
    Accessible.checked: chosen
    Keys.onSpacePressed: picked()

    Rectangle {
        width: 16
        height: 16
        radius: 8
        color: control.chosen && control.front ? Theme.accent.bg
             : control.chosen ? (control.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.16))
             : control.dark ? Qt.rgba(1, 1, 1, 0.085) : Qt.rgba(0, 0, 0, 0.07)
        Rectangle {
            anchors.centerIn: parent
            visible: control.chosen
            width: 6
            height: 6
            radius: 3
            color: control.front ? Theme.accent.fg : control.dark ? "#e2e2e2" : "#ffffff"
        }
    }
    Text {
        id: label
        x: 22.5
        anchors.verticalCenter: parent.verticalCenter
        text: control.text
        color: control.colors.label.primary
        font.family: Theme.uiFont
        font.pixelSize: 13
        renderType: Text.NativeRendering
    }
    MouseArea { anchors.fill: parent; onClicked: control.picked() }
}
