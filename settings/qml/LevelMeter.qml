import QtQuick
import Ambrosia
import Settings

// An input's level as a row of 16 small capsules across a slider's width,
// lit from the left in the accent color as loud as the sound is.
Row {
    id: meter

    property real level: 0 // 0 to 1

    readonly property int count: 16
    spacing: 3
    Accessible.role: Accessible.ProgressBar

    Repeater {
        model: meter.count
        Rectangle {
            required property int index
            width: (Look.sliderWidth - (meter.count - 1) * meter.spacing) / meter.count
            height: 6
            radius: 3
            color: (index + 0.5) / meter.count <= meter.level ? Theme.accent.bg : Look.track
        }
    }
}
