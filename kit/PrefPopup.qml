import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import Qt.labs.platform as Platform
import Ambrosia

// A pop-up button in a Settings window (PreferencesWindow.qml), measured
// from macOS 27's Finder Settings: 24 tall on a rounded fill, the current
// choice 14 in and the up-down chevron at its right end. A click opens
// its menu with the current choice over the button, checked. The menu is
// the platform's (the session's widget style draws it as a Mac's), so it
// reaches past the edges of a small window. It says what was chosen;
// whoever owns the setting sets `current`.
Rectangle {
    id: button

    // [{ text, value }]; an item without a value is a separator.
    property var items: []
    property var current
    signal chosen(var value)

    readonly property bool dark: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark
    readonly property QtObject colors: dark ? Theme.darkColors : Theme.lightColors
    readonly property int currentIndex: items.findIndex(item => item.value === current)
    readonly property string text: items[currentIndex]?.text ?? ""

    implicitWidth: label.implicitWidth + 48
    height: 24
    radius: 6
    color: dark ? Qt.rgba(1, 1, 1, 0.075) : Qt.rgba(0, 0, 0, 0.06)
    activeFocusOnTab: true
    Accessible.role: Accessible.ComboBox
    Accessible.name: text
    Keys.onSpacePressed: open()

    function open() {
        menu.open(over, entries.objectAt(Math.max(0, currentIndex)));
    }
    // Where the menu's current row goes: its top left at this one's bottom
    // left, which puts the row's text over the button's (the menu's rows
    // are 22 tall, their text 40 in).
    Item {
        id: over
        x: -26
        y: -5
        width: 1
        height: 1
    }

    Text {
        id: label
        x: 14
        width: button.width - 14 - 26
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: button.text
        color: button.colors.label.primary
        font.family: Theme.uiFont
        font.pixelSize: 13
        renderType: Text.NativeRendering
    }
    Shape {
        x: button.width - 21
        y: (button.height - 12) / 2
        width: 12
        height: 12
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: button.colors.label.primary
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: "M3.2 4.6L6 1.9l2.8 2.7M3.2 7.4L6 10.1l2.8-2.7" }
        }
    }
    TapHandler { onTapped: button.open() }

    Platform.Menu {
        id: menu

        Instantiator {
            id: entries
            model: button.items
            delegate: Platform.MenuItem {
                required property var modelData
                separator: modelData.value === undefined
                text: modelData.text ?? ""
                checkable: !separator
                checked: !separator && modelData.value === button.current
                onTriggered: button.chosen(modelData.value)
            }
            onObjectAdded: (index, object) => menu.insertItem(index, object)
            onObjectRemoved: (index, object) => menu.removeItem(object)
        }
    }
}
