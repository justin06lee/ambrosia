import QtQuick
import Qt.labs.platform as Platform
import Ambrosia
import DiskUtility

// The toolbar, 66 tall, as Disk Utility's: the lights over the sidebar; the
// View button (the sidebar, and what it lists) and the app's name; from the
// right Info, Unmount or Mount, Erase and First Aid, each a round button
// over its name, gray when it has nothing to do with what is chosen.
// Volume's plus and minus, Partition and Restore are not here: nothing
// behind them yet.
Item {
    id: toolbar

    required property var window
    // Where the part over the page begins.
    readonly property real start: window.sidebarShown ? Look.sidebarWidth : 0
    readonly property real viewX: Math.max(start + Look.viewAfterSidebar, Look.lightsX + 3 * Look.lightPitch + 6)

    height: Look.toolbar

    TrafficLights {
        x: Look.lightsX
        y: Look.lightsY
        window: toolbar.window
    }

    // One button over its name.
    component Tool: Item {
        id: tool
        property string glyph
        property string name
        property bool usable: true
        property real glyphSize: 20
        signal clicked()
        readonly property bool front: toolbar.window.looksActive

        width: Math.max(Look.control, label.implicitWidth)
        height: Look.toolbar

        Capsule {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Look.controlY
            width: Look.control
            Item {
                width: Look.control
                height: Look.control
                Rectangle {
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    radius: 15
                    color: Look.pressed
                    visible: area.pressed && tool.usable
                }
                Glyph {
                    anchors.centerIn: parent
                    name: tool.glyph
                    size: tool.glyphSize
                    color: tool.usable ? (tool.front ? Look.glyph : Look.glyphInactive) : (tool.front ? Look.glyphOff : Look.glyphOffInactive)
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    enabled: tool.usable
                    onClicked: tool.clicked()
                }
            }
        }
        Label {
            id: label
            anchors.horizontalCenter: parent.horizontalCenter
            y: Look.labelY - height / 2
            text: tool.name
            style: Theme.text.footnote
            color: tool.usable ? (tool.front ? Look.toolLabel : Look.toolLabelInactive) : (tool.front ? Look.toolLabelOff : Look.toolLabelOffInactive)
        }
    }

    // View: the sidebar's glyph and a chevron; a menu of what is listed.
    Item {
        id: view
        x: toolbar.viewX
        width: Look.viewWidth
        height: Look.toolbar
        Capsule {
            y: Look.controlY
            width: Look.viewWidth
            Item {
                width: Look.viewWidth
                height: Look.control
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 6
                    height: 30
                    radius: 15
                    color: Look.pressed
                    visible: viewArea.pressed
                }
                Glyph {
                    x: 9
                    anchors.verticalCenter: parent.verticalCenter
                    name: "sidebar"
                    size: 19
                    color: toolbar.window.looksActive ? Look.glyph : Look.glyphInactive
                }
                Glyph {
                    x: 30
                    anchors.verticalCenter: parent.verticalCenter
                    name: "chevronDown"
                    size: 9
                    color: toolbar.window.looksActive ? Look.glyph : Look.glyphInactive
                }
                Item { id: underView; y: Look.control + 4; width: 1; height: 1 }
                MouseArea {
                    id: viewArea
                    anchors.fill: parent
                    onClicked: viewMenu.open(underView)
                }
            }
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Look.labelY - height / 2
            text: "View"
            style: Theme.text.footnote
            color: toolbar.window.looksActive ? Look.toolLabel : Look.toolLabelInactive
        }
    }
    Label {
        x: view.x + Look.viewWidth + Look.titleAfterView
        y: Look.controlY + Look.control / 2 - height / 2
        width: Math.max(0, tools.x - x - 12)
        visible: width >= 60
        elide: Text.ElideRight
        text: "Disk Utility"
        font.pixelSize: 15
        font.weight: 700
        color: toolbar.window.looksActive ? Look.title : Look.titleInactive
    }

    Row {
        id: tools
        anchors.right: parent.right
        anchors.rightMargin: Look.edge
        spacing: Look.toolGap

        Tool {
            glyph: "firstAid"
            name: "First Aid"
            usable: toolbar.window.may.firstAid
            onClicked: toolbar.window.askFirstAid()
        }
        Tool {
            glyph: "erase"
            name: "Erase"
            glyphSize: 21
            usable: toolbar.window.may.erase
            onClicked: toolbar.window.askErase()
        }
        Tool {
            glyph: toolbar.window.may.mountLabel === "Mount" ? "mount" : "unmount"
            name: toolbar.window.may.mountLabel
            usable: toolbar.window.may.mount
            onClicked: toolbar.window.toggleMount()
        }
        Tool {
            glyph: "info"
            name: "Info"
            usable: toolbar.window.may.info
            onClicked: toolbar.window.showInfo()
        }
    }

    Platform.Menu {
        id: viewMenu
        Platform.MenuItem { text: toolbar.window.sidebarShown ? "Hide Sidebar" : "Show Sidebar"; onTriggered: toolbar.window.sidebarShown = !toolbar.window.sidebarShown }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Show Only Volumes"; checkable: true; checked: !toolbar.window.everything; onTriggered: toolbar.window.everything = false }
        Platform.MenuItem { text: "Show All Devices"; checkable: true; checked: toolbar.window.everything; onTriggered: toolbar.window.everything = true }
    }
}
