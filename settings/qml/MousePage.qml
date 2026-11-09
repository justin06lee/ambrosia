import QtQuick
import Ambrosia
import Settings

// Mouse, laid out as macOS 26's (not photographed: the Mac here has no
// mouse): tracking speed, natural scrolling, the secondary click's side,
// double-click and scrolling speed, and Advanced…'s pointer acceleration.
// Every mouse is set alike, through KWin, which keeps it.
Page {
    id: page

    Component.onCompleted: Mouse.read()

    Box {
        FormRow {
            firstLine: Look.sliderKnobHeight
            label: qsTr("Tracking speed")
            Slider {
                trackWidth: 200
                ticks: 10
                captions: [qsTr("Slow"), qsTr("Fast")]
                value: Mouse.speed
                onMoved: (value) => Mouse.speed = value
            }
        }
        FormRow {
            label: qsTr("Natural scrolling")
            description: qsTr("Content tracks finger movement")
            Switch {
                checked: Mouse.naturalScroll
                onToggled: Mouse.naturalScroll = !checked
            }
        }
        FormRow {
            label: qsTr("Secondary click")
            PopUpButton {
                items: [
                    { text: qsTr("Click Right Side"), value: false },
                    { text: qsTr("Click Left Side"), value: true },
                ]
                current: Mouse.leftHanded
                onChosen: (value) => Mouse.leftHanded = value
            }
        }
        FormRow {
            firstLine: Look.sliderKnobHeight
            label: qsTr("Double-click speed")
            Slider {
                trackWidth: 200
                ticks: 11
                captions: [qsTr("Slow"), qsTr("Fast")]
                value: Mouse.doubleClick
                onMoved: (value) => Mouse.doubleClick = value
            }
        }
        FormRow {
            firstLine: Look.sliderKnobHeight
            label: qsTr("Scrolling speed")
            Slider {
                trackWidth: 200
                ticks: 8
                captions: [qsTr("Slow"), qsTr("Fast")]
                value: Mouse.scrollSpeed
                onMoved: (value) => Mouse.scrollSpeed = value
            }
        }
    }
    Item {
        width: parent.width
        height: Look.popupHeight
        PushButton {
            anchors.right: parent.right
            text: qsTr("Advanced…")
            onClicked: advanced.open = true
        }
    }

    Sheet {
        id: advanced
        settings: page.settings
        sheetWidth: 440
        below: 24
        onAccepted: close()
        Box {
            width: parent.width
            FormRow {
                label: qsTr("Pointer acceleration")
                description: qsTr("The faster you move the mouse, the farther the pointer goes.")
                Switch {
                    checked: Mouse.acceleration
                    onToggled: Mouse.acceleration = !checked
                }
            }
        }
        trailing: [
            PushButton {
                text: qsTr("Done")
                primary: true
                minimumWidth: 70
                onClicked: advanced.accepted()
            }
        ]
    }
}
