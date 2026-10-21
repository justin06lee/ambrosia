import QtQuick
import QtQuick.Effects
import Ambrosia

// One of the toolbar's glass capsules: a rounded group of buttons that
// floats on the window with a rim of light and a soft shadow.
Item {
    id: capsule

    default property alias content: row.data
    property real padding: 0

    implicitWidth: row.implicitWidth + 2 * padding
    implicitHeight: Finder.control

    Rectangle {
        id: body
        anchors.fill: parent
        radius: height / 2
        color: Finder.capsule
        border.width: 0.5
        border.color: Finder.capsuleRim
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
        x: capsule.padding
        height: parent.height
    }
}
