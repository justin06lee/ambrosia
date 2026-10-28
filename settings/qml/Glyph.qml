import QtQuick
import QtQuick.Shapes
import Ambrosia
import "glyphs.js" as Glyphs

// A glyph from glyphs.js, drawn as vectors so it is sharp at any scale
// and takes any color (as the shell's Icon.qml).
Item {
    id: glyph

    property string name
    property real size: 16
    property color color: Theme.color.label.primary
    readonly property var shape: Glyphs.glyphs[name] ?? {}
    property real weight: shape.width ?? 1.5

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24
        height: 24
        scale: glyph.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: glyph.shape.stroke ? glyph.color : "transparent"
            strokeWidth: glyph.weight
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: glyph.shape.stroke ?? "" }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: glyph.shape.fill ? glyph.color : "transparent"
            fillRule: ShapePath.WindingFill
            PathSvg { path: glyph.shape.fill ?? "" }
        }
    }
}
