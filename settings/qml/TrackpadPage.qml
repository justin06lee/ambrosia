import QtQuick
import Ambrosia
import Settings

// Trackpad: the rows of macOS 26's pane that a touchpad here can act on
// (KWin's settings for it): tracking speed, the secondary click, tap to
// click and natural scrolling. Left out: the gesture demo and its tabs,
// Click pressure, Quiet Click, Force Click and Look up (Apple's hardware),
// zoom and rotate (each app's own) and More Gestures (KWin's swipes can't
// be chosen), and Set Up Bluetooth Trackpad… (Bluetooth pairs it).
Page {
    id: page

    Component.onCompleted: Trackpad.read()

    Box {
        FormRow {
            firstLine: Look.sliderKnobHeight
            label: qsTr("Tracking speed")
            Slider {
                trackWidth: 200
                ticks: 10
                captions: [qsTr("Slow"), qsTr("Fast")]
                value: Trackpad.speed
                onMoved: (value) => Trackpad.speed = value
            }
        }
        FormRow {
            visible: Trackpad.twoFingerClick && Trackpad.cornerClick
            label: qsTr("Secondary click")
            PopUpButton {
                items: [
                    { text: qsTr("Click or Tap with Two Fingers"), value: "twoFingers" },
                    { text: qsTr("Click in Bottom Right Corner"), value: "corner" },
                ]
                current: Trackpad.secondaryClick
                onChosen: (value) => Trackpad.secondaryClick = value
            }
        }
        FormRow {
            visible: Trackpad.canTap
            label: qsTr("Tap to click")
            description: qsTr("Tap with one finger")
            Switch {
                checked: Trackpad.tapToClick
                onToggled: Trackpad.tapToClick = !checked
            }
        }
    }
    Box {
        FormRow {
            label: qsTr("Natural scrolling")
            description: qsTr("Content tracks finger movement")
            Switch {
                checked: Trackpad.naturalScroll
                onToggled: Trackpad.naturalScroll = !checked
            }
        }
    }
}
