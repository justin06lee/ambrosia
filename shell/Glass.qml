import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Ambrosia
import "icons.js" as Icons

// A glass surface, the recipe of preview/glass.css: the material's tint over
// the compositor's blur (its window lists this item as a blur region), light
// caught along its top edge, a specular ring lit from the top left, a
// hairline edge outside, and an elevation's shadow cast around it but not
// under it, so the glass is only as dark as its tint.
Item {
    id: glass

    property color tint: Theme.color.material.regular.tint
    property real radius: Theme.radius.popover
    // One of Theme.color.shadow's elevations, or null for none.
    property QtObject shadow: null
    // A lit rim all the way round (the Dock's) instead of along the top.
    property bool ring: false

    readonly property int shadowRoom: 64
    readonly property real corner: Math.max(0, Math.min(radius, width / 2, height / 2))
    readonly property color rim: Theme.color.glass.rim

    // The outline, and the same inset by a pixel: between them, a 1px ring.
    readonly property string ringPath: width <= 2 || height <= 2 ? ""
        : Icons.rect(0, 0, width, height, corner) + Icons.rect(1, 1, width - 2, height - 2, Math.max(0, corner - 1))
    // The outline's top, less the same shifted down a pixel: light along the
    // top edge that thins away round the corners (CSS inset 0 1px 0).
    readonly property string topPath: {
        const w = width, r = corner;
        if (w <= 2 * r) return "";
        return `M0 ${r}A${r} ${r} 0 0 1 ${r} 0L${w - r} 0A${r} ${r} 0 0 1 ${w} ${r}` +
            `L${w} ${r + 1}A${r} ${r} 0 0 0 ${w - r} 1L${r} 1A${r} ${r} 0 0 0 0 ${r + 1}Z`;
    }

    Item {
        id: shadows
        visible: glass.shadow !== null
        anchors.fill: parent
        anchors.margins: -glass.shadowRoom
        layer.enabled: visible
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: hole
        }

        Repeater {
            model: glass.shadow?.layers ?? []

            RectangularShadow {
                required property var modelData
                x: glass.shadowRoom + modelData.x
                y: glass.shadowRoom + modelData.y
                width: glass.width
                height: glass.height
                radius: glass.corner
                blur: modelData.blur
                spread: modelData.spread
                color: Qt.alpha(glass.shadow.color, modelData.opacity)
            }
        }
    }

    // The glass's outline, cut out of its shadow.
    Item {
        id: hole
        anchors.fill: shadows
        visible: false
        layer.enabled: true

        Rectangle {
            x: glass.shadowRoom
            y: glass.shadowRoom
            width: glass.width
            height: glass.height
            radius: glass.corner
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: glass.corner
        color: glass.tint
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // The rim: light caught along the top edge, or all the way round.
        ShapePath {
            strokeColor: "transparent"
            fillColor: glass.rim
            fillRule: ShapePath.OddEvenFill
            PathSvg { path: glass.ring ? glass.ringPath : glass.topPath }
        }

        // The specular ring: brightest at the top left, gone through the
        // middle, a little light again at the bottom right (CSS 135deg).
        ShapePath {
            strokeColor: "transparent"
            fillRule: ShapePath.OddEvenFill
            fillGradient: LinearGradient {
                x1: glass.width / 2 - (glass.width + glass.height) / 4
                y1: glass.height / 2 - (glass.width + glass.height) / 4
                x2: glass.width / 2 + (glass.width + glass.height) / 4
                y2: glass.height / 2 + (glass.width + glass.height) / 4
                GradientStop { position: 0; color: glass.rim }
                GradientStop { position: 0.35; color: Qt.alpha(glass.rim, 0) }
                GradientStop { position: 0.7; color: Qt.alpha(glass.rim, 0) }
                GradientStop { position: 1; color: Qt.alpha(glass.rim, glass.rim.a * 0.45) }
            }
            PathSvg { path: glass.ringPath }
        }
    }

    // The edge: a hairline between the glass and what's behind it.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -0.5
        radius: glass.corner + 0.5
        color: "transparent"
        border.width: 0.5
        border.color: Theme.color.glass.edge
    }
}
