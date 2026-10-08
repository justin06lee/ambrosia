import QtQuick
import QtQuick.Shapes
import Ambrosia
import "icons.js" as Icons

// A line icon from icons.js, drawn as vectors so it is sharp at any scale and
// takes any color.
Item {
    id: icon

    property string name
    property real size: Theme.size.menubar.icon
    property color color: Theme.color.label.primary
    readonly property var glyph: Icons.glyphs[name] ?? {}

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24
        height: 24
        scale: icon.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: icon.glyph.stroke ? icon.color : "transparent"
            strokeWidth: 1.5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: icon.glyph.stroke ?? "" }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: icon.glyph.fill ? icon.color : "transparent"
            PathSvg { path: icon.glyph.fill ?? "" }
        }
    }
}
