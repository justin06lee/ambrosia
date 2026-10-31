import QtQuick
import Ambrosia
import Settings

// Desktop & Dock, as System Settings lays it out, with what acts on our side:
// the Dock (the shell draws it), KWin's minimize effect, double-click, edges
// and corners, and the default browser. Left out: Minimize into application
// icon (a minimized window never takes a place of its own), recent apps in
// the Dock (not built), desktop items, Stage Manager and widgets (none here),
// tabs, keep-changes and quit-closes (apps' own), Hold ⌥ and tile margins,
// Mission Control's options, Shortcuts… and the help button.
Page {
    id: page

    SectionHeading {
        first: true
        text: qsTr("Dock")
    }
    Box {
        Item {
            width: parent.width
            height: 68
            Column {
                x: Look.boxPadding
                y: Look.boxPadding
                spacing: 6
                Label { text: qsTr("Size") }
                // From 28 to 96 points; our 52 is a little over a third along.
                Slider {
                    trackWidth: 196
                    ticks: 3
                    captions: [qsTr("Small"), qsTr("Large")]
                    value: (Preferences.dockSize - 28) / 68
                    onMoved: (value) => Preferences.dockSize = Math.round(28 + value * 68)
                }
            }
            Column {
                x: 234
                y: Look.boxPadding
                spacing: 6
                Label { text: qsTr("Magnification") }
                Slider {
                    trackWidth: 216
                    ticks: 3
                    captions: [qsTr("Off"), qsTr("Large")]
                    value: Preferences.dockMagnification
                    onMoved: (value) => Preferences.dockMagnification = value < 0.03 ? 0 : value
                }
            }
        }
    }
    Box {
        FormRow {
            label: qsTr("Dock position on screen")
            PopUpButton {
                items: [
                    { text: qsTr("Left"), value: "left" },
                    { text: qsTr("Bottom"), value: "bottom" },
                    { text: qsTr("Right"), value: "right" },
                ]
                current: Preferences.dockPosition
                onChosen: (value) => Preferences.dockPosition = value
            }
        }
        FormRow {
            label: qsTr("Minimized window animation")
            PopUpButton {
                items: [
                    { text: qsTr("Genie Effect"), value: "genie" },
                    { text: qsTr("Scale Effect"), value: "scale" },
                ]
                current: Windowing.minimizeEffect
                onChosen: (value) => Windowing.minimizeEffect = value
            }
        }
        FormRow {
            label: qsTr("Window title bar double-click action")
            PopUpButton {
                items: [
                    { text: qsTr("Zoom"), value: "Maximize" },
                    { text: qsTr("Minimize"), value: "Minimize" },
                    { text: qsTr("Do Nothing"), value: "Nothing" },
                ]
                current: Windowing.titleBarDoubleClick
                onChosen: (value) => Windowing.titleBarDoubleClick = value
            }
        }
    }
    Box {
        FormRow {
            label: qsTr("Automatically hide and show the Dock")
            Switch {
                checked: Preferences.dockAutohide
                onToggled: Preferences.dockAutohide = !Preferences.dockAutohide
            }
        }
        FormRow {
            label: qsTr("Animate opening applications")
            Switch {
                checked: Preferences.dockBounce
                onToggled: Preferences.dockBounce = !Preferences.dockBounce
            }
        }
        FormRow {
            label: qsTr("Show indicators for open applications")
            Switch {
                checked: Preferences.dockIndicators
                onToggled: Preferences.dockIndicators = !Preferences.dockIndicators
            }
        }
    }
    Box {
        FormRow {
            visible: Windowing.browsers.length > 0
            label: qsTr("Default web browser")
            PopUpButton {
                items: Windowing.browsers
                current: Windowing.browser
                onChosen: (value) => Windowing.browser = value
            }
        }
    }

    SectionHeading { text: qsTr("Windows") }
    Box {
        FormRow {
            label: qsTr("Drag windows to left or right edge of screen to tile")
            Switch {
                checked: Windowing.tileAtEdges
                onToggled: Windowing.tileAtEdges = !Windowing.tileAtEdges
            }
        }
        FormRow {
            label: qsTr("Drag windows to menu bar to fill screen")
            Switch {
                checked: Windowing.fillAtTop
                onToggled: Windowing.fillAtTop = !Windowing.fillAtTop
            }
        }
    }
    Item {
        width: Look.boxWidth
        height: 34
        PushButton {
            x: parent.width - width
            y: 10
            text: qsTr("Hot Corners…")
            onClicked: corners.open = true
        }
    }

    HotCornersSheet {
        id: corners
        settings: page.settings
    }
}
