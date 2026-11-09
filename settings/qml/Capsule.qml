import QtQuick
import QtQuick.Effects
import Ambrosia
import Settings

// A glass capsule on the toolbar (Files' Capsule.qml): a rounded group of
// buttons that floats on the window with a rim of light and a soft shadow.
Item {
    id: capsule

    default property alias content: row.data

    implicitWidth: row.implicitWidth
    implicitHeight: Look.control

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Look.capsule
        border.width: 0.5
        border.color: Look.capsuleRim
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: Theme.dark ? 0.35 : 0.1
            shadowBlur: 0.6
            shadowVerticalOffset: 2
            blurMax: 16
        }
    }
    Row {
        id: row
        height: parent.height
    }
}
