import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import Ambrosia

// A screenshot just taken, small: the picture inside a white edge, a shadow
// under it, as a Mac floats one in the screen's corner. Only the picture:
// Screenshot.qml takes the shot, shows this and opens what is clicked.
Item {
    id: thumb

    property url source

    // The picture keeps its shape inside the box the tokens give it; until
    // it is read, the box.
    readonly property real box: Theme.size.screenshot.height / Theme.size.screenshot.width
    readonly property real shape: picture.status === Image.Ready && picture.implicitWidth > 0
        ? picture.implicitHeight / picture.implicitWidth : box

    implicitWidth: Math.round(shape > box ? Theme.size.screenshot.height / shape : Theme.size.screenshot.width)
    implicitHeight: Math.round(shape > box ? Theme.size.screenshot.height : Theme.size.screenshot.width * shape)
    width: implicitWidth
    height: implicitHeight

    Repeater {
        model: Theme.color.shadow.panel.layers

        RectangularShadow {
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: thumb.width
            height: thumb.height
            radius: Theme.size.screenshot.radius
            blur: modelData.blur
            color: Qt.alpha(Theme.color.shadow.panel.color, modelData.opacity)
        }
    }
    // The edge is white in light and dark, as a Mac's is: it frames a
    // picture, not a control.
    ClippingRectangle {
        anchors.fill: parent
        radius: Theme.size.screenshot.radius
        color: "white"

        ClippingRectangle {
            anchors.fill: parent
            anchors.margins: Theme.size.screenshot.border
            radius: Theme.size.screenshot.radius - Theme.size.screenshot.border
            color: "transparent"

            Image {
                id: picture
                anchors.fill: parent
                source: thumb.source
                // A big picture, shown small: read at the size it is shown.
                sourceSize.width: 2 * Theme.size.screenshot.width
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }
        }
    }
}
