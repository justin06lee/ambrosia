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
                    menu.about = "";
                    menu.open();
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
                                menu.about = row.modelData.fixed ? "" : row.modelData.key;
                                menu.open();
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
        id: menu
        // The folder it is about, or none (a click on nothing, or on one
        // that can't be changed).
        property string about: ""
        Platform.MenuItem { text: "New Folder"; onTriggered: sidebar.window.newFolder() }
        Platform.MenuSeparator { visible: menu.about !== "" }
        Platform.MenuItem { visible: menu.about !== ""; text: "Rename Folder"; onTriggered: sidebar.window.renaming = menu.about }
        Platform.MenuItem { visible: menu.about !== ""; text: "Delete Folder"; onTriggered: sidebar.window.deleteFolder(menu.about) }
    }
}
