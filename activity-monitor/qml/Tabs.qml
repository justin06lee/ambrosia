import QtQuick
import Ambrosia
import ActivityMonitor
import "monitor.mjs" as Monitor

// CPU, Memory, Energy, Disk and Network on one capsule, 74 each, the one in
// view on a lighter face 68 by 28.
Item {
    id: tabs

    required property Window window

    implicitWidth: Monitor.tabs.length * Look.tabWidth
    implicitHeight: Look.control

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Look.capsule
        border.width: 0.5
        border.color: Look.capsuleRim
    }
    Rectangle {
        readonly property int at: Math.max(0, Monitor.tabs.findIndex(tab => tab.key === tabs.window.tabKey))
        x: at * Look.tabWidth + 3
        y: (parent.height - Look.tabFace) / 2
        width: Look.tabWidth - 6
        height: Look.tabFace
        radius: height / 2
        color: Look.tabChosen
    }
    Repeater {
        model: Monitor.tabs
        Item {
            id: tab
            required property var modelData
            required property int index
            readonly property bool chosen: tabs.window.tabKey === modelData.key
            x: index * Look.tabWidth
            width: Look.tabWidth
            height: tabs.height

            Label {
                anchors.centerIn: parent
                text: tab.modelData.title
                font.weight: 500
                color: !tabs.window.looksActive ? (tab.chosen ? Qt.lighter(Look.glyphInactive, 1.2) : Look.glyphInactive) : Look.glyph
            }
            MouseArea {
                anchors.fill: parent
                onPressed: tabs.window.tabKey = tab.modelData.key
            }
        }
    }
}
