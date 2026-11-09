import QtQuick
import QtQuick.Effects
import Ambrosia
import Settings

// A user's picture in a circle, or a person on gray where they have none.
Item {
    id: picture

    property string source: ""
    implicitWidth: 32
    implicitHeight: 32

    Rectangle {
        anchors.fill: parent
        visible: picture.source === ""
        radius: width / 2
        color: Theme.dark ? "#8e8e93" : "#aeaeb2"
        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            name: "person"
            size: parent.width * 0.9
            color: "#ffffff"
        }
    }
    Image {
        id: image
        anchors.fill: parent
        visible: false
        source: picture.source
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width * 2, height * 2)
        asynchronous: true
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        visible: false
        radius: width / 2
        layer.enabled: true
        layer.smooth: true
    }
    MultiEffect {
        anchors.fill: parent
        visible: picture.source !== ""
        source: image
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
    }
}
