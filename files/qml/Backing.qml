import QtQuick
import QtQuick.Shapes

// The window's own color, everywhere but under a pane of glass: a hole the
// shape of the pane, a pixel inside its edge (the pane's tint and rim lie
// over the seam), so the desktop shows through the glass and nowhere else.
Shape {
    id: backing

    property color color
    property real radius: 0
    // The pane, in this item's coordinates, and its corner.
    property rect hole
    property real holeRadius: 0
    // Closed, it is the whole window again.
    property bool open: true

    function rounded(x, y, w, h, r) {
        r = Math.max(0, Math.min(r, w / 2, h / 2));
        return `M${x + r} ${y}H${x + w - r}A${r} ${r} 0 0 1 ${x + w} ${y + r}V${y + h - r}`
            + `A${r} ${r} 0 0 1 ${x + w - r} ${y + h}H${x + r}A${r} ${r} 0 0 1 ${x} ${y + h - r}`
            + `V${y + r}A${r} ${r} 0 0 1 ${x + r} ${y}Z`;
    }

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: "transparent"
        fillColor: backing.color
        fillRule: ShapePath.OddEvenFill
        PathSvg {
            path: backing.width < 4 || backing.height < 4 ? ""
                : backing.rounded(0, 0, backing.width, backing.height, backing.radius)
                    + (backing.open && backing.hole.width > 4 && backing.hole.height > 4
                        ? backing.rounded(backing.hole.x + 1, backing.hole.y + 1, backing.hole.width - 2,
                                          backing.hole.height - 2, backing.holeRadius - 1)
                        : "")
        }
    }
}
