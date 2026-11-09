import QtQuick
import QtQuick.Effects
import Settings

// A wallpaper in small with rounded corners: a color, a picture, or two
// pictures side by side (Nectar's day and night).
Item {
    id: picture

    property color color: "black"
    property url source
    property url second // shown over the right half
    property int fillMode: Image.PreserveAspectCrop
    property real radius: Look.tileRadius

    Item {
        id: content
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true
        Rectangle {
            anchors.fill: parent
            color: picture.color
        }
        Image {
            anchors.fill: parent
            source: picture.source
            sourceSize: Qt.size(picture.width * 2, picture.height * 2)
            fillMode: picture.fillMode
            autoTransform: true
            asynchronous: true
            smooth: true
        }
        Item {
            visible: picture.second.toString() !== ""
            x: parent.width / 2
            width: parent.width / 2
            height: parent.height
            clip: true
            Image {
                x: -parent.width
                width: picture.width
                height: picture.height
                source: picture.second
                sourceSize: Qt.size(picture.width * 2, picture.height * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
        }
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        visible: false
        radius: picture.radius
        layer.enabled: true
        layer.smooth: true
    }
    MultiEffect {
        anchors.fill: parent
        source: content
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
}
