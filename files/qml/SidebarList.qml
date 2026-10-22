import QtQuick
import Ambrosia
import Files

// What both sidebars list: Finder's sections (the top items, Favorites,
// Locations, Tags). A click goes to a place; items dropped on a folder
// move or copy into it, and on the Trash go to the Trash.
Flickable {
    id: list

    required property var finder
    // How far the rows sit from the sidebar's left edge, beyond the
    // floating panel's (the flush sidebar starts at the window's edge).
    property real leading: 0

    contentHeight: sections.implicitHeight + 16
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: sections
        width: parent.width
        spacing: Finder.sidebarGap

        Repeater {
            model: Places.sections
            Column {
                id: section
                required property var modelData
                width: sections.width

                Label {
                    visible: section.modelData.title !== ""
                    x: list.leading + Finder.sidebarIconX - 5
                    height: Finder.sidebarHeader
                    verticalAlignment: Text.AlignVCenter
                    text: section.modelData.title
                    style: Theme.text.caption
                    font.weight: 600
                    color: Theme.color.label.secondary
                }
                Repeater {
                    model: section.modelData.items
                    Item {
                        id: row
                        required property var modelData
                        readonly property string place: modelData.url !== undefined ? modelData.url.toString() : ""
                        readonly property bool current: place !== "" && list.finder.url.toString() === place
                        // A folder on this computer, or the Trash.
                        readonly property bool takesDrops: (place.startsWith("file:///") && place !== "file:///") || place.startsWith("trash:")
                        width: section.width
                        height: Finder.sidebarRow

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: list.leading + 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 2
                            anchors.bottomMargin: 2
                            radius: 8
                            color: drop.containsDrag ? Theme.accent.bg : Theme.color.fill.secondary
                            visible: row.current || drop.containsDrag
                        }
                        Glyph {
                            visible: row.modelData.glyph !== undefined
                            x: list.leading + Finder.sidebarIconX - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            name: row.modelData.glyph ?? ""
                            size: Finder.sidebarGlyph
                            color: drop.containsDrag ? Theme.accent.fg : Theme.color.label.secondary
                        }
                        Rectangle {
                            // A tag's color dot.
                            visible: row.modelData.color !== undefined
                            x: list.leading + Finder.sidebarIconX - width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: 12
                            height: 12
                            radius: 6
                            color: row.modelData.color ? Theme.color.palette[row.modelData.color] : "transparent"
                        }
                        Label {
                            x: list.leading + Finder.sidebarLabelX - Finder.sidebarInset + 8
                            width: parent.width - x - 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.name
                            elide: Text.ElideRight
                            color: drop.containsDrag ? Theme.accent.fg : Theme.color.label.primary
                        }
                        TapHandler {
                            onTapped: if (row.place !== "") list.finder.go(row.modelData.url)
                        }
                        DropArea {
                            id: drop
                            anchors.fill: parent
                            enabled: row.takesDrops
                            keys: ["text/uri-list"]
                            onEntered: (drag) => drag.accept(Qt.MoveAction)
                            onDropped: (drop) => drop.accept(list.finder.dropOn(drop.urls, row.modelData.url))
                        }
                    }
                }
            }
        }
    }
}
