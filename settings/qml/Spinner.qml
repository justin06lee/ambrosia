import QtQuick
import Ambrosia
import Settings

// The busy spinner by a heading while it looks (Wi-Fi's Other Networks):
// eight spokes round a 16 point circle, fading behind the one in front as
// it turns, a step at a time.
Item {
    id: spinner

    property bool running: true
    property int step: 0

    implicitWidth: 16
    implicitHeight: 16
    visible: running

    Repeater {
        model: 8
        Rectangle {
            required property int index
            x: (spinner.width - width) / 2
            y: 0.5
            width: 1.8
            height: 4.4
            radius: width / 2
            color: Theme.color.label.secondary
            opacity: 0.25 + 0.75 * ((index - spinner.step + 8) % 8) / 7
            transform: Rotation { origin.x: 0.9; origin.y: spinner.height / 2 - 0.5; angle: index * 45 }
        }
    }
    Timer {
        interval: 90
        repeat: true
        running: spinner.running && spinner.visible
        onTriggered: spinner.step = (spinner.step + 1) % 8
    }
}
