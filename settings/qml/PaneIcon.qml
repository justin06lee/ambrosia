import QtQuick
import Ambrosia
import Settings

// A pane's icon, as System Settings draws them: a rounded square in the
// pane's color, lit from above, with its glyph in white. 20 points in the
// sidebar and in a page's rows, 52 in a pane's header.
Rectangle {
    id: icon

    property string glyph
    property string tint: "gray"
    property real size: Look.icon
    readonly property var colors: Look.tints[tint] ?? Look.tints.gray

    width: size
    height: size
    radius: size * Theme.radius.iconCorner
    gradient: Gradient {
        GradientStop { position: 0; color: icon.colors[0] }
        GradientStop { position: 1; color: icon.colors[1] }
    }
    // A black square keeps its edge on a dark sidebar.
    border.width: icon.tint === "black" && Theme.dark ? 0.5 : 0
    border.color: "#33ffffff"

    Glyph {
        anchors.centerIn: parent
        name: icon.glyph
        size: icon.size * 0.72
        color: "white"
    }
}
