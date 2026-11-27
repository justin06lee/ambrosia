import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Window
import Ambrosia
import DiskUtility

// A disk's or volume's Info window, 480 by 302 as macOS 27's (Look.qml):
// its name on a bar 32 tall, and under it what is known of it in rows 19
// apart, every other one on a band (disks.mjs info()). It follows the
// thing: a volume mounted while it is open says so.
Window {
    id: win

    // The key of what it is about, its name, and its rows [name, value].
    property string key
    property string name
    property var rows: []

    property int menusOpen: 0
    property bool shellOpen: false
    readonly property bool looksActive: active || menusOpen > 0 || shellOpen || App.active
    readonly property int corner: Look.infoRadius
    onActiveChanged: if (active) menusOpen = 0

    function takeKeys() {
        keys.forceActiveFocus();
    }
    function toggleZoom() {
        visibility === Window.Maximized ? showNormal() : showMaximized();
    }

    width: Look.infoWidth
    height: Look.infoHeight
    minimumWidth: 320
    minimumHeight: 140
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: name + " Info"

    readonly property Appearance appearance: Appearance {}
    onVisibleChanged: if (visible) App.decorate(win, Look.infoRadius)
    Component.onCompleted: takeKeys()

    Shortcut { sequences: ["Ctrl+W", "Meta+W"]; onActivated: win.close() }
    Shortcut { sequences: ["Ctrl+M", "Meta+M"]; onActivated: win.showMinimized() }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: win.visibility === Window.Maximized ? 0 : win.corner
        color: Look.infoGround
        clip: true

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: win.close()
        }

        Flickable {
            id: list
            y: Look.titleBar
            width: parent.width
            height: parent.height - y - 6
            contentHeight: column.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: ScrollThumb {}

            Column {
                id: column
                width: list.width
                Repeater {
                    model: win.rows
                    Rectangle {
                        required property var modelData
                        required property int index
                        width: column.width
                        height: Look.infoRow
                        color: index % 2 === 1 ? Look.infoBand : "transparent"
                        Label {
                            x: 18
                            width: 232
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: modelData[0]
                            color: Look.text
                        }
                        Label {
                            x: 258
                            width: Math.max(0, parent.width - x - 14)
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideMiddle
                            text: modelData[1]
                            color: Look.text
                        }
                    }
                }
            }
        }

        // The title bar: the window moves by it.
        Rectangle {
            width: parent.width
            height: Look.titleBar
            topLeftRadius: frame.radius
            topRightRadius: frame.radius
            color: Look.infoBar
            DragHandler {
                target: null
                onActiveChanged: if (active) win.startSystemMove()
            }
            TapHandler { onDoubleTapped: win.toggleZoom() }
            TrafficLights {
                x: 9
                y: 9
                window: win
            }
            Label {
                x: 86
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - 16
                elide: Text.ElideRight
                text: win.title
                font.weight: 700
                color: win.looksActive ? Look.title : Look.titleInactive
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: frame.radius
            color: "transparent"
            border.width: 0.5
            border.color: Look.rim
        }

        // Resizing by the edges and corners.
        Repeater {
            model: [
                { edges: Qt.LeftEdge, x: 0, y: 8, w: 5, h: -16, shape: Qt.SizeHorCursor },
                { edges: Qt.RightEdge, x: -5, y: 8, w: 5, h: -16, shape: Qt.SizeHorCursor },
                { edges: Qt.TopEdge, x: 8, y: 0, w: -16, h: 4, shape: Qt.SizeVerCursor },
                { edges: Qt.BottomEdge, x: 8, y: -5, w: -16, h: 5, shape: Qt.SizeVerCursor },
                { edges: Qt.BottomEdge | Qt.LeftEdge, x: 0, y: -10, w: 10, h: 10, shape: Qt.SizeBDiagCursor },
                { edges: Qt.BottomEdge | Qt.RightEdge, x: -10, y: -10, w: 10, h: 10, shape: Qt.SizeFDiagCursor },
            ]
            Item {
                required property var modelData
                x: modelData.x < 0 ? frame.width + modelData.x : modelData.x
                y: modelData.y < 0 ? frame.height + modelData.y : modelData.y
                width: modelData.w < 0 ? frame.width + modelData.w : modelData.w
                height: modelData.h < 0 ? frame.height + modelData.h : modelData.h
                HoverHandler { cursorShape: parent.modelData.shape }
                DragHandler {
                    target: null
                    onActiveChanged: if (active) win.startSystemResize(parent.modelData.edges)
                }
            }
        }
    }
}
