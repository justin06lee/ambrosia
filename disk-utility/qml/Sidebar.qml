import QtQuick
import QtQuick.Controls.Basic as Controls
import Qt.labs.platform as Platform
import Ambrosia
import DiskUtility

// The sidebar, 256 wide, flush and as tall as the window: the volumes, or
// every disk with its volumes under it, beneath Internal, External and Disk
// Images (disks.mjs sidebar()). The chosen one stands on a rounded fill;
// one that isn't mounted is written dim; what can be ejected has the mark
// for it at its right.
Item {
    id: sidebar

    required property var window
    readonly property var parts: window.sections

    width: Look.sidebarWidth

    // Where the row of this key is: how far down the list and how far in;
    // null when it isn't listed.
    function place(key) {
        let y = 0;
        for (const section of parts) {
            y += Look.sidebarRow;
            for (const entry of section.rows) {
                if (entry.key === key)
                    return { y: y, level: entry.level, name: entry.name };
                y += Look.sidebarRow;
            }
        }
        return null;
    }

    Rectangle {
        anchors.fill: parent
        topLeftRadius: sidebar.window.corner
        bottomLeftRadius: sidebar.window.corner
        color: Look.sidebarFill
    }
    // The window moves by the sidebar's top, as by its toolbar.
    Item {
        width: parent.width
        height: Look.sidebarTop
        DragHandler {
            target: null
            onActiveChanged: if (active) sidebar.window.startSystemMove()
        }
        TapHandler { onDoubleTapped: sidebar.window.toggleZoom() }
    }

    Flickable {
        id: flick
        y: Look.sidebarTop
        width: parent.width
        height: parent.height - y
        contentHeight: column.height + 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Controls.ScrollBar.vertical: ScrollThumb {}

        // The name being changed, over its row: one field for the list,
        // which is built again whenever the disks are read.
        Loader {
            id: editor
            readonly property var at: sidebar.window.renaming === "" ? null : sidebar.place(sidebar.window.renaming)
            active: at !== null
            z: 1
            x: Look.sidebarTextX + (at?.level ?? 0) * Look.sidebarIndent - 5
            y: (at?.y ?? 0) + (Look.sidebarRow - 22) / 2
            width: parent.width - x - Look.sidebarInset - 4
            height: 22
            // No longer listed (ejected while its name was typed).
            onAtChanged: if (at === null && sidebar.window.renaming !== "") sidebar.window.rename(sidebar.window.renaming, "")
            sourceComponent: Rectangle {
                radius: 5
                color: Look.field
                border.width: 2
                border.color: Theme.accent.bg
                TextInput {
                    x: 5
                    width: parent.width - 10
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    color: Look.sidebarText
                    selectionColor: Theme.accent.highlight
                    selectedTextColor: Look.sidebarText
                    selectByMouse: true
                    renderType: Text.NativeRendering
                    Accessible.role: Accessible.EditableText
                    Accessible.name: "Volume name"
                    property bool done: false
                    property string key
                    function finish(keep) {
                        if (done)
                            return;
                        done = true;
                        sidebar.window.rename(key, keep ? text : "");
                    }
                    Component.onCompleted: {
                        // (The loader's own bindings may not have caught up.)
                        key = sidebar.window.renaming;
                        text = editor.at?.name ?? "";
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

        Column {
            id: column
            width: parent.width

            Repeater {
                model: sidebar.parts

                Column {
                    id: part
                    required property var modelData
                    width: column.width

                    Item {
                        width: parent.width
                        height: Look.sidebarRow
                        Label {
                            x: 16
                            y: 23 - height / 2
                            text: part.modelData.title
                            style: Theme.text.footnote
                            font.weight: 600
                            color: sidebar.window.looksActive ? Look.sidebarHeading : Look.sidebarHeadingInactive
                        }
                    }
                    Repeater {
                        model: part.modelData.rows

                        Item {
                            id: row
                            required property var modelData
                            readonly property bool chosen: sidebar.window.chosen === modelData.key
                            readonly property bool renaming: sidebar.window.renaming !== "" && sidebar.window.renaming === modelData.key
                            readonly property real indent: modelData.level * Look.sidebarIndent
                            readonly property color ink: modelData.dim
                                ? (sidebar.window.looksActive ? Look.sidebarDim : Look.sidebarDimInactive)
                                : (sidebar.window.looksActive ? Look.sidebarText : Look.sidebarTextInactive)
                            width: column.width
                            height: Look.sidebarRow

                            Rectangle {
                                visible: row.chosen
                                x: Look.sidebarInset
                                width: parent.width - 2 * Look.sidebarInset
                                height: parent.height
                                radius: 8
                                color: sidebar.window.looksActive ? Look.sidebarChosen : Look.sidebarChosenInactive
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                // A click on the name of what is chosen
                                // already changes the name, a moment
                                // later: two clicks don't.
                                property bool onName: false
                                onPressed: (mouse) => {
                                    onName = row.chosen && mouse.button === Qt.LeftButton && mouse.x >= name.x && mouse.x <= name.x + Math.min(name.width, name.implicitWidth);
                                    slow.stop();
                                    sidebar.window.choose(row.modelData.key);
                                    if (mouse.button === Qt.RightButton)
                                        menu.open();
                                }
                                onClicked: if (onName && sidebar.window.may.rename) slow.restart()
                                onDoubleClicked: slow.stop()
                                Timer {
                                    id: slow
                                    interval: 600
                                    onTriggered: if (row.chosen) sidebar.window.startRename()
                                }
                            }
                            // Shut or open, for a disk with volumes under it.
                            Item {
                                visible: row.modelData.children
                                x: Look.sidebarChevronX + row.indent - 9
                                width: 18
                                height: parent.height
                                Glyph {
                                    anchors.centerIn: parent
                                    name: row.modelData.shut ? "chevronRight" : "chevronDown"
                                    size: 11
                                    color: sidebar.window.looksActive ? Look.sidebarGlyph : Look.sidebarGlyphInactive
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: sidebar.window.toggleShut(row.modelData.key)
                                }
                            }
                            Glyph {
                                x: Look.sidebarGlyphX + row.indent - size / 2
                                anchors.verticalCenter: parent.verticalCenter
                                name: row.modelData.glyph
                                size: 19
                                color: row.modelData.dim ? row.ink : sidebar.window.looksActive ? Look.sidebarGlyph : Look.sidebarGlyphInactive
                            }
                            Label {
                                id: name
                                visible: !row.renaming
                                x: Look.sidebarTextX + row.indent
                                width: parent.width - x - (row.modelData.eject ? 40 : 16)
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: row.modelData.name
                                font.weight: row.chosen ? 600 : 500
                                color: row.ink
                            }
                            Item {
                                visible: row.modelData.eject && !row.renaming
                                x: parent.width - Look.sidebarEjectX - 11
                                width: 22
                                height: parent.height
                                Glyph {
                                    anchors.centerIn: parent
                                    name: "eject"
                                    size: 13
                                    color: ejectArea.pressed ? Look.sidebarText : sidebar.window.looksActive ? Look.sidebarHeading : Look.sidebarHeadingInactive
                                }
                                MouseArea {
                                    id: ejectArea
                                    anchors.fill: parent
                                    onClicked: sidebar.window.eject(row.modelData.key)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // What is chosen, by a right click: the toolbar's deeds.

    Platform.Menu {
        id: menu
        Platform.MenuItem { text: "Get Info"; enabled: sidebar.window.may.info; onTriggered: sidebar.window.showInfo() }
        Platform.MenuItem { text: "Rename"; enabled: sidebar.window.may.rename; onTriggered: sidebar.window.startRename() }
        Platform.MenuItem { text: "Show in Files"; enabled: sidebar.window.item?.mounted ?? false; onTriggered: sidebar.window.reveal() }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: sidebar.window.may.mountLabel; enabled: sidebar.window.may.mount; onTriggered: sidebar.window.toggleMount() }
        Platform.MenuItem { text: "Eject"; enabled: sidebar.window.may.eject; onTriggered: sidebar.window.eject(sidebar.window.chosen) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Run First Aid…"; enabled: sidebar.window.may.firstAid; onTriggered: sidebar.window.askFirstAid() }
        Platform.MenuItem { text: "Erase…"; enabled: sidebar.window.may.erase; onTriggered: sidebar.window.askErase() }
    }
}
