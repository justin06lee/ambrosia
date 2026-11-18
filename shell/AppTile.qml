import QtQuick
import QtQuick.Shapes
import Ambrosia
import "icons.js" as Icons

// An app's icon in its place. One of ours is drawn on its tile already; any
// other (Firefox's fox, Breeze's own) is set on a plain tile of the same
// shape, as macOS 26 does with an icon that wasn't drawn for it, so a row of
// apps is a row of tiles. The place is an icon's whole canvas: the tile sits
// in it with the margin our icons have (design/icons.ts).
//
// Only QtQuick, so KWin's switcher can use it too. The icon is whatever is
// put inside, filling its parent.
Item {
    id: tile

    // Whether the icon has a tile of its own.
    property bool tiled: true
    default property alias icon: holder.data

    // A tile's side on its canvas, and a plain icon's on the tile.
    readonly property real side: width * 208 / 256
    readonly property real inset: 0.74

    Shape {
        visible: !tile.tiled
        x: (tile.width - tile.side) / 2
        y: (tile.height - tile.side) / 2
        width: tile.side
        height: tile.side
        preferredRendererType: Shape.CurveRenderer

        // The tile, with a hair of shade so it holds on a white ground.
        ShapePath {
            strokeColor: Qt.rgba(0, 0, 0, 0.12)
            strokeWidth: Math.max(1, tile.side / 208)
            fillGradient: LinearGradient {
                y2: tile.side
                GradientStop { position: 0; color: "#ffffff" }
                GradientStop { position: 1; color: "#e4e4e9" }
            }
            PathSvg { path: Icons.squircle(0, 0, tile.side) }
        }
    }

    Item {
        id: holder
        anchors.centerIn: parent
        width: tile.tiled ? tile.width : Math.round(tile.side * tile.inset)
        height: tile.tiled ? tile.height : width
    }
}
