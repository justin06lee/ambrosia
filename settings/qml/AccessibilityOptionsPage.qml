import QtQuick
import Ambrosia
import Settings

// One of Accessibility's pages (the window's anchor says which): Zoom,
// Display, Motion, Audio, Keyboard or Pointer Control, each with the rows
// of the Mac's page that KWin or KDE's settings act on.
Page {
    id: page

    readonly property string kind: settings.anchor

    Component.onCompleted: Access.read()

    // Zoom
    Box {
        visible: page.kind === "zoom"
        FormRow {
            label: qsTr("Use keyboard shortcuts to zoom")
            description: Access.zoomInKeys !== "" && Access.zoomOutKeys !== ""
                ? qsTr("Zoom in: %1   Zoom out: %2").arg(Access.zoomInKeys).arg(Access.zoomOutKeys) : ""
            Switch {
                checked: Access.zoom
                onToggled: Access.zoom = !checked
            }
        }
        FormRow {
            visible: Access.zoom && Access.scrollZoomKeys !== ""
            label: qsTr("Use scroll gesture with modifier keys to zoom")
            value: Access.scrollZoomKeys
        }
        FormRow {
            label: qsTr("Zoom style")
            opacity: Access.zoom ? 1 : 0.5
            PopUpButton {
                enabled: Access.zoom
                items: [
                    { text: qsTr("Full Screen"), value: "full" },
                    { text: qsTr("Picture-in-Picture"), value: "lens" },
                ]
                current: Access.zoomStyle
                onChosen: (value) => Access.zoomStyle = value
            }
        }
    }

    // Display
    Box {
        visible: page.kind === "display"
        FormRow {
            label: qsTr("Color filters")
            Switch {
                checked: Access.colorFilters
                onToggled: Access.colorFilters = !checked
            }
        }
        FormRow {
            label: qsTr("Filter type")
            PopUpButton {
                items: [
                    { text: qsTr("Red/Green filter (Protanopia)"), value: 0 },
                    { text: qsTr("Green/Red filter (Deuteranopia)"), value: 1 },
                    { text: qsTr("Blue/Yellow filter (Tritanopia)"), value: 2 },
                ]
                current: Access.colorFilter
                onChosen: (value) => Access.colorFilter = value
            }
        }
    }
    SectionHeading {
        visible: page.kind === "display"
        text: qsTr("Pointer")
    }
    Box {
        visible: page.kind === "display"
        FormRow {
            label: qsTr("Shake mouse pointer to locate")
            description: qsTr("Quickly move the mouse pointer back and forth to make it bigger.")
            Switch {
                checked: Access.shakeToLocate
                onToggled: Access.shakeToLocate = !checked
            }
        }
        FormRow {
            firstLine: Look.sliderKnobHeight
            label: qsTr("Pointer size")
            Slider {
                trackWidth: 200
                ticks: 5
                snaps: true
                captions: [qsTr("Normal"), qsTr("Large")]
                value: Access.pointerSize
                onMoved: (value) => Access.pointerSize = value
            }
        }
    }

    // Motion
    Box {
        visible: page.kind === "motion"
        FormRow {
            label: qsTr("Reduce motion")
            description: qsTr("Reduce the movement of windows and menus as they open and close.")
            Switch {
                checked: Access.reduceMotion
                onToggled: Access.reduceMotion = !checked
            }
        }
        FormRow {
            label: qsTr("Prefer non-blinking cursor")
            description: qsTr("Applies to apps as they next open.")
            Switch {
                checked: Access.steadyCursor
                onToggled: Access.steadyCursor = !checked
            }
        }
    }

    // Audio
    Box {
        visible: page.kind === "audio"
        FormRow {
            label: qsTr("Flash the screen when an alert sound occurs")
            Switch {
                checked: Access.flashScreen
                onToggled: Access.flashScreen = !checked
            }
        }
    }

    // Keyboard
    Box {
        visible: page.kind === "keyboard"
        FormRow {
            label: qsTr("Sticky Keys")
            description: qsTr("Press modifier keys one at a time for a key combination, without holding them.")
            Switch {
                checked: Access.stickyKeys
                onToggled: Access.stickyKeys = !checked
            }
        }
        FormRow {
            label: qsTr("Slow Keys")
            description: qsTr("A key must be held for a moment before it's taken.")
            Switch {
                checked: Access.slowKeys
                onToggled: Access.slowKeys = !checked
            }
        }
    }

    // Pointer Control
    Box {
        visible: page.kind === "pointer"
        FormRow {
            label: qsTr("Mouse Keys")
            description: qsTr("Move the pointer with the numeric keypad.")
            Switch {
                checked: Access.mouseKeys
                onToggled: Access.mouseKeys = !checked
            }
        }
    }
}
