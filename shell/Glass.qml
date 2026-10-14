import QtQuick
import QtQuick.Effects
import Ambrosia

// A glass surface: the material's tint over the compositor's blur (its window
// lists this item as a blur region), a lit rim inside, a hairline edge
// outside, and an elevation's shadow cast around it but not under it, so the
// glass is only as dark as its tint.
Item {
    id: glass

    property color tint: Theme.color.material.regular.tint
    property real radius: Theme.radius.popover
    // One of Theme.color.shadow's elevations, or null for none.
    property QtObject shadow: null

    readonly property int shadowRoom: 64

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
                radius: glass.radius
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
            radius: glass.radius
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: glass.radius
        color: glass.tint
    }

    // The rim: light caught along the glass's inner edge.
    Rectangle {
        anchors.fill: parent
        radius: glass.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.color.glass.rim
        opacity: 0.6
    }

    // The edge: a hairline between the glass and what's behind it.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -0.5
        radius: glass.radius + 0.5
        color: "transparent"
        border.width: 0.5
        border.color: Theme.color.glass.edge
    }
}
