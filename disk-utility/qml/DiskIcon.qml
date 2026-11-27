import QtQuick
import DiskUtility

// A disk's picture, 64 across: a drive standing on its foot with one
// light, gray for one inside the computer, amber with a plug's mark for
// one plugged in, white with a folded corner's line for a disk image. Our
// own shapes.
Item {
    id: icon

    // internal, external or image
    property string kind: "internal"
    readonly property var tones: kind === "external" ? ["#ffc24a", "#f29a1c", "#c9c9cc", "#a15d08"]
        : kind === "image" ? ["#fbfbfc", "#dcdce0", "#b9b9be", "#9a9aa0"]
        : ["#c9c9ce", "#8e8e94", "#6a6a70", "#56565b"]

    width: 64
    height: 64

    Rectangle {
        x: 10
        y: 5
        width: 44
        height: 54
        radius: 5
        gradient: Gradient {
            GradientStop { position: 0; color: icon.tones[0] }
            GradientStop { position: 1; color: icon.tones[1] }
        }
        border.width: 0.5
        border.color: Qt.rgba(0, 0, 0, 0.25)

        // What it is, pressed into its face.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            width: 16
            height: 26
            opacity: icon.kind === "internal" ? 0.55 : 0.8
            // A plug and its cable.
            Rectangle { visible: icon.kind === "external"; x: 5; y: 0; width: 6; height: 5; radius: 1; color: icon.tones[3] }
            Rectangle { visible: icon.kind === "external"; x: 3.5; y: 4; width: 9; height: 8; radius: 1.5; color: icon.tones[3] }
            Rectangle { visible: icon.kind === "external"; x: 7; y: 12; width: 2; height: 12; radius: 1; color: icon.tones[3] }
            // A platter and its spindle.
            Rectangle { visible: icon.kind === "internal"; x: 0; y: 4; width: 16; height: 16; radius: 8; color: "transparent"; border.width: 2; border.color: icon.tones[3] }
            Rectangle { visible: icon.kind === "internal"; x: 6; y: 10; width: 4; height: 4; radius: 2; color: icon.tones[3] }
            // A page's lines.
            Repeater {
                model: icon.kind === "image" ? 4 : 0
                Rectangle {
                    required property int index
                    y: 4 + index * 5
                    width: index === 3 ? 10 : 16
                    height: 2
                    radius: 1
                    color: icon.tones[3]
                }
            }
        }
        // Its foot, and the light on it.
        Rectangle {
            y: parent.height - 9
            width: parent.width
            height: 9
            bottomLeftRadius: 5
            bottomRightRadius: 5
            color: icon.tones[2]
            Rectangle { x: parent.width - 8; y: 3; width: 3; height: 3; radius: 1.5; color: "#f4f4f6" }
        }
    }
}
