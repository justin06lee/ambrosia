import QtQuick
import Ambrosia
import Settings

// An input's level as System Settings shows it: 15 upright capsules, 7 × 15
// and 10 apart, lit from the left in the accent color as loud as the sound
// is; it ends 7 short of the row's right, as there.
Row {
    id: meter

    property real level: 0 // 0 to 1

    readonly property int count: 15
    spacing: 10
    rightPadding: 7
    Accessible.role: Accessible.ProgressBar

    Repeater {
        model: meter.count
        Rectangle {
            required property int index
            width: 7
            height: 15
            radius: width / 2
            color: (index + 0.5) / meter.count <= meter.level ? Theme.accent.bg : Look.track
        }
    }
}
