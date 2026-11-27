import QtQuick
import QtQuick.Controls.Basic as Controls
import Qt.labs.platform as Platform
import Ambrosia
import Notes
import "notes.mjs" as Logic

// The sidebar, 228 wide, flush and as tall as the window: under "On My
// Computer" the folders (notes.mjs sidebar()), each with how many notes it
// holds. The chosen one stands on a rounded fill, its glyph in Notes'
// yellow. Two clicks on a folder of one's own, or Return, change its name
// in place; a right click offers that and deleting it.
Item {
    id: sidebar

    required property var window
    readonly property var folders: window.side
    readonly property bool front: window.looksActive

    width: Look.sidebarWidth

    // The folder at a place in the window that would take a note dragged
    // out of `from`: any but the one it is in and the one that is all of
    // them. Nothing when there is none there.
    function folderAt(px, py, from) {
        if (px < 0 || px >= width || py < flick.y)
            return "";
        const at = Math.floor((py - flick.y + flick.contentY - Look.sidebarHeading) / Look.sidebarRow);
        const entry = at >= 0 && at < folders.length ? folders[at] : null;
        return entry && entry.key !== Logic.everything && entry.key !== from ? entry.key : "";
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: sidebar.window.corner
        bottomLeftRadius: sidebar.window.corner
        color: Look.sidebarFill
    }
    // The window moves by the sidebar's top, as by its bar.
    Item {
        width: parent.width
        height: Look.toolbar
        DragHandler {
            target: null
            onActiveChanged: if (active) sidebar.window.startSystemMove()
        }
        TapHandler { onDoubleTapped: sidebar.window.toggleZoom() }
    }

    Flickable {
        id: flick
        y: Look.toolbar
        width: parent.width
        height: parent.height - y
        contentHeight: column.height + 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: ScrollThumb {}

        // A click on nothing: the keys are the sidebar's.
        MouseArea {
            width: flick.width
            height: Math.max(flick.height, flick.contentHeight)
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                sidebar.window.focusSidebar();
                if (mouse.button === Qt.RightButton) {
                    folderMenu.about = "";
                    folderMenu.open();
                }
            }
        }

        Column {
            id: column
            width: flick.width

            Item {
                width: parent.width
                height: Look.sidebarHeading
                Label {
                    x: Look.sidebarGlyphX + 1
                    y: 12 - baselineOffset
                    text: "On My Computer"
                    style: Theme.text.footnote
                    font.weight: 700
                    color: sidebar.front ? Look.sidebarHeadingInk : Look.sidebarHeadingInactive
                }
            }

            Repeater {
                model: sidebar.folders

                Item {
                    id: row
                    required property var modelData
                    readonly property bool chosen: modelData.key === sidebar.window.folder
                    readonly property bool renaming: sidebar.window.renaming !== "" && sidebar.window.renaming === modelData.key

                    width: column.width
                    height: Look.sidebarRow
                    Accessible.role: Accessible.ListItem
                    Accessible.name: modelData.name

                    Rectangle {
                        visible: row.chosen
                        x: Look.sidebarInset
                        y: 1
                        width: parent.width - 2 * Look.sidebarInset
                        height: parent.height - 2
                        radius: 8
                        color: sidebar.front ? Look.sidebarChosen : Look.sidebarChosenInactive
                    }
                    // A dragged note would land here.
                    Rectangle {
                        visible: sidebar.window.dropFolder !== "" && sidebar.window.dropFolder === row.modelData.key
                        x: Look.sidebarInset
                        y: 1
                        width: parent.width - 2 * Look.sidebarInset
                        height: parent.height - 2
                        radius: 8
                        color: row.chosen ? "transparent" : Look.sidebarChosen
                        border.width: 2
                        border.color: Look.tint
                    }
                    Glyph {
                        x: Look.sidebarGlyphX - 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        name: row.modelData.glyph
                        size: 21
                        weight: 1.4
                        color: !sidebar.front ? Look.sidebarGlyphInactive : row.modelData.key === Logic.deleted ? Look.sidebarText : Look.tint
                    }
                    Label {
                        id: name
                        visible: !row.renaming
                        x: Look.sidebarTextX
                        width: count.x - x - 6
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: row.modelData.name
                        color: sidebar.front ? Look.sidebarText : Look.sidebarTextInactive
                    }
                    Label {
                        id: count
                        visible: !row.renaming
                        x: parent.width - Look.sidebarCountInset - width
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.count
                        color: sidebar.front ? Look.sidebarCount : Look.sidebarCountInactive
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            sidebar.window.chooseFolder(row.modelData.key);
                            sidebar.window.focusSidebar();
                            if (mouse.button === Qt.RightButton) {
                                folderMenu.about = row.modelData.fixed ? "" : row.modelData.key;
                                folderMenu.open();
                            }
                        }
                        onDoubleClicked: {
                            if (!row.modelData.fixed)
                                sidebar.window.renaming = row.modelData.key;
                        }
                    }
                    // The name, being changed.
                    Loader {
                        active: row.renaming
                        x: Look.sidebarTextX - 5
                        width: parent.width - x - Look.sidebarInset - 4
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        sourceComponent: Rectangle {
                            radius: 5
                            color: Look.field
                            border.width: 2
                            border.color: Look.tint
                            TextInput {
                                id: input
                                x: 5
                                width: parent.width - 10
                                anchors.verticalCenter: parent.verticalCenter
                                clip: true
                                text: row.modelData.name
                                font.family: Theme.uiFont
                                font.pixelSize: 13
                                color: Look.sidebarText
                                selectionColor: Look.selection
                                selectedTextColor: Look.sidebarText
                                selectByMouse: true
                                renderType: Text.NativeRendering
                                Accessible.role: Accessible.EditableText
                                Accessible.name: "Folder name"
                                property bool done: false
                                function finish(keep) {
                                    if (done)
                                        return;
                                    done = true;
                                    sidebar.window.renameFolder(row.modelData.key, keep ? text : row.modelData.key);
                                }
                                Component.onCompleted: {
                                    forceActiveFocus();
                                    selectAll();
                                }
                                Keys.onReturnPressed: finish(true)
                                Keys.onEnterPressed: finish(true)
                                Keys.onEscapePressed: finish(false)
                                onActiveFocusChanged: if (!activeFocus) finish(true)
                            }
                        }
                    }
                }
            }
        }
    }

    Platform.Menu {
        id: folderMenu
        // The folder it is about, or none (a click on nothing, or on one
        // that can't be changed).
        property string about: ""
        Platform.MenuItem { text: "New Folder"; onTriggered: sidebar.window.newFolder() }
        Platform.MenuSeparator { visible: folderMenu.about !== "" }
        Platform.MenuItem { visible: folderMenu.about !== ""; text: "Rename Folder"; onTriggered: sidebar.window.renaming = folderMenu.about }
        Platform.MenuItem { visible: folderMenu.about !== ""; text: "Delete Folder"; onTriggered: sidebar.window.deleteFolder(folderMenu.about) }
    }
}
