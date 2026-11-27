import QtQuick
import Ambrosia
import Files

// What both sidebars list: Finder's sections (the top items, Favorites,
// Locations, Tags). A click goes to a place; items dropped on a folder
// move or copy into it, and on the Trash go to the Trash. Another disk is
// mounted by its first click, and has an eject button while it is.
Flickable {
    id: list

    required property var finder
    // How far the rows sit from the sidebar's left edge, beyond the
    // floating panel's (the flush sidebar starts at the window's edge).
    property real leading: 0
    // The disk this window asked for, until it is mounted and shown.
    property string opening: ""
    Connections {
        target: Places
        function onOpened(volume, url) {
            if (volume !== list.opening)
                return;
            list.opening = "";
            list.finder.go(url);
        }
    }

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
                        // Another disk, mounted: its eject button is the row's right end.
                        readonly property bool ejectable: modelData.ejectable === true
                        readonly property bool busy: modelData.busy === true
                        // Under a drag, but for the blink before it springs open.
                        readonly property bool dropLit: drop.containsDrag && !(list.finder.springDim && !row.current)
                        readonly property bool renaming: modelData.color !== undefined && list.finder.tagRenaming === modelData.name
                        width: section.width
                        height: Finder.sidebarRow
                        opacity: busy && !ejectable ? 0.5 : 1 // being mounted

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: list.leading + 8
                            anchors.rightMargin: 8
                            anchors.topMargin: 2
                            anchors.bottomMargin: 2
                            radius: 8
                            color: row.dropLit ? Theme.accent.bg : Theme.color.fill.secondary
                            visible: row.current || row.dropLit
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
                            id: title
                            visible: !row.renaming
                            x: list.leading + Finder.sidebarLabelX - Finder.sidebarInset + 8
                            width: parent.width - x - (row.ejectable ? eject.width + 12 : 10)
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.name
                            elide: Text.ElideRight
                            color: drop.containsDrag ? Theme.accent.fg : Theme.color.label.primary
                        }
                        // A tag being renamed (its menu's Rename): a field
                        // over its name. Return or a click elsewhere takes
                        // the new name, Esc leaves the old.
                        Loader {
                            active: row.renaming
                            x: title.x - 5
                            width: title.width + 5
                            anchors.verticalCenter: parent.verticalCenter
                            sourceComponent: Rectangle {
                                id: field
                                property bool done: false
                                function end(take) {
                                    if (done)
                                        return;
                                    done = true;
                                    const from = row.modelData.name, to = input.text;
                                    const shown = list.finder.tagShown && row.current;
                                    list.finder.tagRenaming = "";
                                    if (take && Tags.rename(from, to) && shown)
                                        list.finder.go(Places.sections.flatMap(section => section.items).find(item => item.color !== undefined && item.name === to.trim())?.url ?? Places.place("home"));
                                }
                                height: input.contentHeight + 4
                                radius: 3
                                color: Finder.content
                                border.width: 1
                                border.color: Theme.accent.bg
                                TextInput {
                                    id: input
                                    anchors.fill: parent
                                    anchors.leftMargin: 5
                                    anchors.rightMargin: 5
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    text: row.modelData.name
                                    font.family: Theme.uiFont
                                    font.pixelSize: Theme.text.body.size
                                    font.weight: Theme.text.body.weight
                                    font.letterSpacing: Theme.text.body.tracking
                                    color: Theme.color.label.primary
                                    selectionColor: Theme.accent.bg
                                    selectedTextColor: Theme.accent.fg
                                    selectByMouse: true
                                    renderType: Text.NativeRendering
                                    Keys.onReturnPressed: field.end(true)
                                    Keys.onEnterPressed: field.end(true)
                                    Keys.onEscapePressed: field.end(false)
                                    onActiveFocusChanged: if (!activeFocus) field.end(true)
                                    Component.onCompleted: {
                                        forceActiveFocus();
                                        selectAll();
                                    }
                                }
                            }
                        }
                        Item {
                            id: eject
                            visible: row.ejectable
                            x: parent.width - width - 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20
                            height: 20
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Theme.color.fill.secondary
                                visible: overEject.hovered && !row.busy
                            }
                            Glyph {
                                anchors.centerIn: parent
                                name: "eject"
                                size: 16
                                color: drop.containsDrag ? Theme.accent.fg : Theme.color.label.secondary
                                opacity: row.busy ? 0.4 : 1 // being ejected
                            }
                            HoverHandler { id: overEject }
                        }
                        TapHandler {
                            onTapped: (point) => {
                                if (row.ejectable && point.position.x >= eject.x - 2) {
                                    Places.eject(row.modelData.volume);
                                } else if (row.place !== "") {
                                    list.finder.go(row.modelData.url);
                                } else if (row.modelData.volume !== undefined) {
                                    list.opening = row.modelData.volume;
                                    Places.open(row.modelData.volume);
                                }
                            }
                        }
                        // A tag's menu sets its color.
                        TapHandler {
                            enabled: row.modelData.color !== undefined
                            acceptedButtons: Qt.RightButton
                            onTapped: (point) => list.finder.tagMenu(row.modelData.name, point.scenePosition.x, point.scenePosition.y)
                        }
                        DropArea {
                            id: drop
                            anchors.fill: parent
                            enabled: row.takesDrops
                            keys: ["text/uri-list"]
                            onEntered: (drag) => {
                                drag.accept(Qt.MoveAction);
                                // A folder springs open; the Trash doesn't.
                                list.finder.springOver(row.place.startsWith("trash:") ? "" : row.modelData.url);
                            }
                            onExited: list.finder.springLeft()
                            onDropped: (drop) => drop.accept(list.finder.dropOn(drop.urls, row.modelData.url))
                        }
                    }
                }
            }
        }
    }
}
