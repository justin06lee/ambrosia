import QtQuick

// Stands in for org.ambrosia.glass's GlassPane (glass/qml), which tells the
// compositor where a pane of glass is: here there is no compositor to tell.
Item {
    property string material: "regular"
    property real radius: 0
    readonly property bool available: false
}
