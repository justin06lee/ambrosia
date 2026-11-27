import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Window
import Ambrosia
import FontBook
import "fontbook.mjs" as Book

// A font file that isn't on the computer, opened: 500 by 432 as macOS 27's
// (Look.qml), its name on a bar 32 tall, a pop-up of its styles and one
// of what to show (its alphabet or every character), the sample, and
// Install, which copies the file into the user's fonts.
Window {
    id: win

    // The file's address, and what the Library read of it (inspect).
    property string file
    property var told: ({ styles: [], family: "", loaded: "" })
    property int styleAt: 0
    property string showing: "sample"
    readonly property var style: told.styles[styleAt] ?? null
    signal installed(string family)

    property int menusOpen: 0
    property bool shellOpen: false
    readonly property bool looksActive: active || menusOpen > 0 || shellOpen || App.active
    readonly property int corner: Look.previewRadius
    readonly property color ink: looksActive ? Look.text : Look.textInactive
    onActiveChanged: if (active) menusOpen = 0

    function takeKeys() {
        keys.forceActiveFocus();
    }
    function toggleZoom() {
    }
    function install() {
        const done = Library.install([win.file]);
        if (done.installed.length > 0) {
            win.installed(done.installed[0]);
            win.close();
        } else {
            failed.visible = true;
        }
    }

    width: Look.previewWidth
    height: Look.previewHeight
    minimumWidth: width
    maximumWidth: width
    minimumHeight: height
    maximumHeight: height
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: told.family

    readonly property Appearance appearance: Appearance {}
    onVisibleChanged: {
        if (visible) {
            App.decorate(win, Look.previewRadius);
            Qt.callLater(App.shown, win, true);
        }
    }
    Component.onCompleted: takeKeys()

    Shortcut { sequences: ["Ctrl+W", "Meta+W"]; onActivated: win.close() }
    Shortcut { sequences: ["Ctrl+M", "Meta+M"]; onActivated: win.showMinimized() }

    Repertoire {
        id: repertoire
        file: win.showing === "repertoire" ? (win.style?.file ?? "") : ""
        index: win.style?.index ?? 0
    }

    Rectangle {
        anchors.fill: parent
        radius: win.corner
        color: Look.previewGround

        Item {
            id: keys
            focus: true
            Keys.onReturnPressed: win.install()
            Keys.onEnterPressed: win.install()
            Keys.onEscapePressed: win.close()
        }

        // The title bar: the window moves by it.
        Rectangle {
            width: parent.width
            height: Look.titleBar
            topLeftRadius: win.corner
            topRightRadius: win.corner
            color: Look.previewBarFill
            DragHandler {
                target: null
                onActiveChanged: if (active) win.startSystemMove()
            }
            TrafficLights {
                x: 9
                y: 9
                window: win
                zoomable: false
            }
            Label {
                x: 86
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - 16
                elide: Text.ElideRight
                text: win.told.family
                font.weight: 700
                color: win.looksActive ? Look.title : Look.titleInactive
            }
        }
        Rectangle { y: Look.titleBar; width: parent.width; height: 1; color: Look.hairline }

        PrefPopup {
            x: 16
            y: 48
            width: 230
            below: true
            enabled: win.told.styles.length > 1
            opacity: enabled ? 1 : 0.55
            items: win.told.styles.map((style, index) => ({ text: style.name, value: index }))
            current: win.styleAt
            onChosen: (value) => win.styleAt = value
        }
        PrefPopup {
            x: 254
            y: 48
            width: 230
            items: [{ text: "Default Sample", value: "sample" }, { text: "Repertoire", value: "repertoire" }]
            current: win.showing
            onChosen: (value) => win.showing = value
        }

        Item {
            y: 84
            width: parent.width
            height: parent.height - y - Look.previewBar - 1
            clip: true

            // As large as fits: a font with tall lines is drawn smaller.
            Text {
                visible: win.showing === "sample"
                x: 20
                y: 6
                width: parent.width - 40
                height: parent.height - 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WrapAnywhere
                fontSizeMode: Text.Fit
                minimumPixelSize: 12
                text: win.told.styles.length > 0 ? Book.specimen(win.told) : ""
                font.family: win.told.loaded
                font.styleName: win.style?.name ?? ""
                font.pixelSize: 34
                color: win.ink
            }
            GridView {
                visible: win.showing === "repertoire"
                x: 20
                width: parent.width - 20
                height: parent.height
                topMargin: 8
                bottomMargin: 8
                cellWidth: 46
                cellHeight: 46
                model: repertoire
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.vertical: ScrollThumb {}
                delegate: Item {
                    id: cell
                    required property string glyph
                    width: 46
                    height: 46
                    Rectangle {
                        width: 38
                        height: 38
                        radius: 6
                        color: Look.cardFill
                        border.width: 1
                        border.color: Look.cardRim
                        Text {
                            anchors.centerIn: parent
                            text: cell.glyph
                            font.family: win.told.loaded
                            font.styleName: win.style?.name ?? ""
                            font.pixelSize: 19
                            color: win.ink
                        }
                    }
                }
            }
        }

        // The buttons' bar.
        Rectangle {
            y: parent.height - Look.previewBar
            width: parent.width
            height: Look.previewBar
            bottomLeftRadius: win.corner
            bottomRightRadius: win.corner
            color: Look.previewBarFill
            Rectangle { width: parent.width; height: 1; color: Look.previewRule }
            Label {
                id: failed
                visible: false
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "The font couldn’t be installed."
                color: Look.note
            }
            PushButton {
                x: parent.width - 16 - width
                y: 11
                width: Math.max(60, implicitWidth)
                text: "Install"
                primary: win.looksActive
                onClicked: win.install()
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: win.corner
            color: "transparent"
            border.width: 0.5
            border.color: Look.rim
        }
    }
}
