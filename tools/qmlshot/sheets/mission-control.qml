import QtQuick
import Ambrosia
import "../../../session/kwin-effects/ambrosia_mission/contents/ui"

// Mission Control's own parts, where KWin isn't: the desktops' strip with
// names only and opened to pictures, and a window's name under the window
// the pointer is on. The windows and the wallpaper are stand-ins (in KWin
// they are the real ones, spread by its layout, and the strip has the
// wallpaper blurred behind it); the ring is drawn here as MissionScreen.qml
// draws it.
Rectangle {
    id: sheet

    width: 1180
    height: 700
    color: shotDark ? "#101014" : "#d8d8dc"

    Binding { target: Theme; property: "dark"; value: shotDark }

    component Wallpaper: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0; color: shotDark ? "#1d2a44" : "#8fb4de" }
            GradientStop { position: 1; color: shotDark ? "#4a2f3a" : "#eebd97" }
        }
    }

    component Window: Rectangle {
        property string title
        property bool lit: false
        property color tile: "#127eee"

        radius: Theme.radius.window * 0.5
        color: shotDark ? "#2a2a2e" : "#fbfbfa"

        Rectangle {
            anchors.fill: parent
            anchors.margins: -Theme.size.mission.ring
            radius: parent.radius + Theme.size.mission.ring
            color: "transparent"
            border.width: Theme.size.mission.ring
            border.color: Theme.accent.bg
            visible: parent.lit
        }

        WindowLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: Theme.size.mission.gap
            visible: parent.lit
            maxWidth: Math.max(parent.width, 240)
            text: parent.title
            icon: Rectangle { anchors.fill: parent; radius: width * 0.22; color: parent.parent.parent.tile }
        }
    }

    component Screen: Item {
        id: screen

        property alias open: bar.open
        property var spaces

        width: 1100
        height: 300
        clip: true

        Wallpaper { anchors.fill: parent }

        // The menu bar's place.
        Rectangle { width: parent.width; height: 28; color: Theme.color.material.thin.tint }

        SpacesBar {
            id: bar
            y: 28
            width: parent.width
            height: implicitHeight
            aspect: 16 / 10
            spaces: screen.spaces
            shot: Wallpaper {
                Rectangle {
                    visible: parent.parent.entry.windows > 0
                    x: parent.width * 0.12; y: parent.height * 0.18
                    width: parent.width * 0.5; height: parent.height * 0.55
                    radius: 2; color: shotDark ? "#2a2a2e" : "#fbfbfa"
                }
                Rectangle {
                    visible: parent.parent.entry.windows > 1
                    x: parent.width * 0.48; y: parent.height * 0.36
                    width: parent.width * 0.4; height: parent.height * 0.5
                    radius: 2; color: shotDark ? "#3a3a3e" : "#ececea"
                }
            }
        }

        Window { x: 150; y: bar.y + bar.height + 26; width: 300; height: 150 - (screen.open ? 60 : 0); title: "Notes.txt" }
        Window {
            x: 520; y: bar.y + bar.height + 26; width: 360; height: 150 - (screen.open ? 60 : 0)
            title: "ambrosia: zsh"; lit: true; tile: "#2a2a2e"
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.space.s8

        Screen {
            spaces: [{ name: "Desktop 1", current: true, windows: 2 }, { name: "Desktop 2", current: false, windows: 1 }]
        }
        Screen {
            open: true
            spaces: [{ name: "Desktop 1", current: false, windows: 2 }, { name: "Desktop 2", current: true, windows: 1 },
                     { name: "Desktop 3", current: false, windows: 0 }]
        }
    }
}
