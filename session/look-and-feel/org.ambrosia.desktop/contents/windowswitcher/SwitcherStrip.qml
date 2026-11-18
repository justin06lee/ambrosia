import QtQuick
import Ambrosia

// ⌘Tab's picture: the running apps as a row of large icons on glass, the
// chosen one on a soft square with its name under it. Only the picture:
// WindowSwitcher.qml gives it KWin's list and keys, and a sheet draws it
// where KWin isn't (tools/qmlshot/sheets/switcher.qml).
Item {
    id: strip

    // Rows with at least a `caption`.
    property var model
    property int currentIndex: 0
    // The widest it may be; with more apps than fit, the icons shrink.
    property real maxWidth: 1200
    // Draws one app's icon, filling its parent, whose `entry` is the row.
    property Component icon
    // What to call a row's app.
    property var nameOf: entry => entry.caption
    signal chosen(int index)
    signal pointed(int index)

    readonly property int count: apps.count
    readonly property int pad: Theme.size.switcher.pad
    readonly property int margin: Theme.size.switcher.margin
    readonly property int iconSize: Math.max(Theme.size.switcher.minimum,
        Math.min(Theme.size.switcher.icon, Math.floor((maxWidth - 2 * margin) / Math.max(1, count)) - 2 * pad))
    readonly property int cell: iconSize + 2 * pad
    // The highlight's corner follows the icon's, the strip's the highlight's.
    readonly property real corner: iconSize * Theme.radius.iconCorner + pad

    implicitWidth: Math.max(1, count) * cell + 2 * margin
    implicitHeight: cell + Theme.size.switcher.label + margin + margin / 2

    Glass {
        anchors.fill: parent
        tint: Theme.color.material.thick.tint
        radius: strip.corner + strip.margin
        shadow: Theme.color.shadow.panel
        ring: true
    }

    Row {
        x: strip.margin
        y: strip.margin

        Repeater {
            id: apps
            model: strip.model

            delegate: Item {
                id: app

                required property int index
                required property var model
                readonly property bool current: index === strip.currentIndex

                width: strip.cell
                height: strip.cell + Theme.size.switcher.label
                // The chosen app's name may run wider than its icon.
                z: current ? 1 : 0

                Rectangle {
                    visible: app.current
                    width: strip.cell
                    height: strip.cell
                    radius: strip.corner
                    color: Theme.color.fill.primary
                }

                Loader {
                    readonly property var entry: app.model
                    x: strip.pad
                    y: strip.pad
                    width: strip.iconSize
                    height: strip.iconSize
                    sourceComponent: strip.icon
                }

                Label {
                    visible: app.current
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: strip.cell
                    height: Theme.size.switcher.label
                    text: app.current ? strip.nameOf(app.model) : ""
                    style: Theme.text.callout
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: strip.pointed(app.index)
                    onClicked: strip.chosen(app.index)
                }
            }
        }
    }
}
