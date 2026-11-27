import QtQuick
import QtQuick.Window
import Ambrosia
import Preview

// Preview's Settings, from the Preview menu or ⌘,: the kit's window at
// macOS 27 Preview Settings' 500, its three tabs laid out as the Mac's by
// measure (Dark, 2026-11-28; a page's y is the Mac's less its 88 of bar
// and tabs): each row's name ends at 194 (General) or 152 and its control
// begins 9.5 after. Only what our Preview does is here, so the pages are
// shorter: no annotations' name, no scale for pictures, no page layouts,
// no logical page numbers, no 3D. Each control sets Prefs, which every
// window reads live.
PreferencesWindow {
    id: settings

    wide: 500
    title: tabs[current].title
    tabs: [
        { title: "General", glyph: "gear", page: general },
        { title: "Images", glyph: "pictures", page: images },
        { title: "PDF", glyph: "page", page: pdf },
    ]

    // A row's name, ending where the Mac's does, its middle at `mid`.
    component Name: Text {
        property real mid
        property real edge: 152
        x: edge - implicitWidth
        y: mid - height / 2
        color: settings.colors.label.primary
        font.family: Theme.uiFont
        font.pixelSize: 13
        renderType: Text.NativeRendering
    }

    Component {
        id: general
        Item {
            implicitHeight: 66
            Name { text: "Window background:"; edge: 194; mid: 33 }
            // The color behind a picture or a PDF's pages: a click picks one.
            Rectangle {
                id: well
                x: 203
                y: 20
                width: 46
                height: 26
                radius: 13
                color: settings.dark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.1)
                Accessible.role: Accessible.Button
                Accessible.name: "Window background"
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: height / 2
                    color: Prefs.ground !== "" ? Prefs.ground : Look.ground
                    border.width: 0.5
                    border.color: settings.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.15)
                }
                MouseArea {
                    anchors.fill: parent
                    // The Colors panel (the kit's): each color chosen
                    // there is the ground at once.
                    onClicked: Colors.show(Prefs.ground !== "" ? Prefs.ground : Look.ground, (color) => Prefs.ground = color.toString(), settings)
                }
            }
            Rectangle {
                x: 269
                y: 21
                width: 58
                height: 24
                radius: 6
                color: reset.pressed ? (settings.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.12)) : settings.dark ? Qt.rgba(1, 1, 1, 0.075) : Qt.rgba(0, 0, 0, 0.06)
                opacity: Prefs.ground !== "" ? 1 : 0.5
                Accessible.role: Accessible.Button
                Accessible.name: "Reset"
                Text {
                    anchors.centerIn: parent
                    text: "Reset"
                    color: settings.colors.label.primary
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    renderType: Text.NativeRendering
                }
                MouseArea {
                    id: reset
                    anchors.fill: parent
                    onClicked: Prefs.ground = ""
                }
            }
        }
    }
    Component {
        id: images
        Item {
            implicitHeight: 74
            Name { text: "When opening files:"; mid: 28.5 }
            PrefRadio {
                x: 161.5
                y: 20.5
                text: "Open groups of files in the same window"
                chosen: !Prefs.separate
                onPicked: Prefs.separate = false
            }
            PrefRadio {
                x: 161.5
                y: 38.5
                text: "Open each file in its own window"
                chosen: Prefs.separate
                onPicked: Prefs.separate = true
            }
        }
    }
    Component {
        id: pdf
        Item {
            implicitHeight: 113
            Name { text: "Define 100% scale as:"; mid: 28 }
            PrefRadio {
                x: 161.5
                y: 20
                text: "1 point equals 1 screen pixel"
                chosen: !Prefs.printout
                onPicked: Prefs.printout = false
            }
            PrefRadio {
                x: 161.5
                y: 38
                text: "Size on screen equals size on printout"
                chosen: Prefs.printout
                onPicked: Prefs.printout = true
            }
            Name { text: "When opening PDFs:"; mid: 85 }
            PrefCheck {
                x: 161.5
                y: 77
                text: "Start on the last viewed page"
                checked: Prefs.lastPage
                onToggled: Prefs.lastPage = !Prefs.lastPage
            }
        }
    }
}
