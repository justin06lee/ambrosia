import QtQuick
import Qt.labs.platform as Platform
import Ambrosia
import Notes

// The bar, 52 tall, in the three parts Notes has it: over the sidebar the
// lights, New Folder and the button that shuts the sidebar; over the list
// the folder's name and count and the list's options; over the note New
// Note, the Format group (the Format menu and Checklist), what else can be
// done with the note, and the search button, which opens into a field.
// Table, Media, Markup, Writing Tools and Share are not here: nothing
// behind them yet.
Item {
    id: toolbar

    required property var window
    readonly property bool front: window.looksActive
    readonly property real listX: window.listX
    readonly property real noteX: window.noteX
    // Where the Format menu hangs from.
    readonly property real formatCenter: group.x + Look.groupCell / 2

    height: Look.toolbar

    function focusSearch() {
        window.searching = true;
        field.forceActiveFocus();
        field.selectAll();
    }

    TrafficLights {
        x: Look.lightsX
        y: Look.lightsY
        window: toolbar.window
    }

    // A round button on its own.
    component Round: Capsule {
        id: round
        property alias glyph: button.glyph
        property alias glyphSize: button.glyphSize
        property alias usable: button.usable
        property string name
        signal clicked()
        y: Look.controlY
        width: Look.control
        Accessible.role: Accessible.Button
        Accessible.name: name
        ToolButton {
            id: button
            window: toolbar.window
            onClicked: round.clicked()
        }
    }

    Round {
        visible: toolbar.window.sidebarShown
        x: Look.sidebarWidth - Look.edge - 2 * Look.control - Look.gap
        glyph: "folderPlus"
        glyphSize: 25
        name: "New Folder"
        onClicked: toolbar.window.newFolder()
    }
    Round {
        id: shut
        x: toolbar.window.sidebarShown ? Look.sidebarWidth - Look.edge - Look.control : Look.lightsX + 3 * Look.lightPitch + 4
        glyph: "sidebar"
        glyphSize: 23.5
        name: toolbar.window.sidebarShown ? "Hide Folders" : "Show Folders"
        onClicked: toolbar.window.sidebarShown = !toolbar.window.sidebarShown
    }

    // The folder and how many notes it holds.
    Item {
        id: heading
        x: toolbar.window.sidebarShown ? toolbar.listX + Look.listTitleX : shut.x + Look.control + 12
        width: Math.max(0, options.x - x - 8)
        height: Look.toolbar
        clip: true
        Label {
            y: Look.listTitleBase - baselineOffset
            width: parent.width
            elide: Text.ElideRight
            text: toolbar.window.searching && toolbar.window.query.trim() !== "" ? "Search" : toolbar.window.folderTitle
            font.pixelSize: 13
            font.weight: 700
            color: toolbar.front ? Look.title : Look.titleInactive
        }
        Label {
            y: Look.listCountBase - baselineOffset
            width: parent.width
            elide: Text.ElideRight
            text: toolbar.window.countTitle
            style: Theme.text.footnote
            color: toolbar.front ? Look.subtitle : Look.titleInactive
        }
    }
    Round {
        id: options
        x: toolbar.listX + Look.listWidth - Look.edge - Look.control
        glyph: "more"
        glyphSize: 20
        name: "View Options"
        Item { id: underOptions; y: Look.control + 4; width: 1; height: 1 }
        onClicked: optionsMenu.open(underOptions)
    }

    Round {
        id: compose
        x: toolbar.noteX + Look.composeX
        glyph: "compose"
        glyphSize: 21.5
        name: "New Note"
        onClicked: toolbar.window.newNote()
    }

    Capsule {
        id: group
        x: compose.x + Look.control + Look.groupAfterCompose
        y: Look.controlY
        visible: x + width < more.x - 8
        // Aa, as the Mac writes it.
        Item {
            width: Look.groupCell
            height: Look.control
            Accessible.role: Accessible.Button
            Accessible.name: "Format"
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 6
                height: 28
                radius: 14
                color: Look.pressed
                visible: formatArea.pressed || toolbar.window.formatShown
            }
            Label {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 0.5
                text: "Aa"
                font.pixelSize: 17
                font.weight: 500
                color: !toolbar.window.editable ? Look.glyphOff : toolbar.front ? Look.glyph : Look.glyphInactive
            }
            MouseArea {
                id: formatArea
                anchors.fill: parent
                enabled: toolbar.window.editable
                onClicked: toolbar.window.formatShown = !toolbar.window.formatShown
            }
        }
        ToolButton {
            width: Look.groupCell
            window: toolbar.window
            glyph: "checklist"
            glyphSize: 23.5
            usable: toolbar.window.editable
            Accessible.role: Accessible.Button
            Accessible.name: "Checklist"
            onClicked: toolbar.window.format("check")
        }
    }

    Round {
        id: more
        visible: !toolbar.window.searching
        x: search.x - Look.gap - Look.control
        glyph: "more"
        glyphSize: 20
        name: "More"
        usable: toolbar.window.open !== null
        Item { id: underMore; y: Look.control + 4; width: 1; height: 1 }
        onClicked: moreMenu.open(underMore)
    }
    Round {
        id: search
        visible: !toolbar.window.searching
        x: toolbar.width - Look.edge - Look.control
        glyph: "search"
        glyphSize: 21.5
        name: "Search"
        onClicked: toolbar.focusSearch()
    }

    // The search button opened into its field.
    Capsule {
        id: finder
        visible: toolbar.window.searching
        x: Math.max(compose.x + Look.control + 12, toolbar.width - Look.edge - width)
        y: Look.controlY
        width: Math.min(240, toolbar.width - Look.edge - compose.x - Look.control - 12)
        Item {
            width: finder.width
            height: Look.control
            Glyph {
                x: 11
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 16
                color: Look.subtitle
            }
            TextInput {
                id: field
                x: 33
                width: parent.width - x - 30
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                font.family: Theme.uiFont
                font.pixelSize: 13
                color: Look.title
                selectionColor: Look.selection
                selectedTextColor: Look.title
                selectByMouse: true
                renderType: Text.NativeRendering
                Accessible.role: Accessible.EditableText
                Accessible.name: "Search"
                onTextEdited: toolbar.window.query = text
                Keys.onEscapePressed: toolbar.window.endSearch()
                Keys.onDownPressed: toolbar.window.focusList()
                Keys.onReturnPressed: toolbar.window.focusList()
                onActiveFocusChanged: {
                    // Left with nothing typed: a button again.
                    if (!activeFocus && text === "")
                        toolbar.window.endSearch();
                }
                Label {
                    visible: field.text === ""
                    text: "Search"
                    color: Look.subtitle
                }
            }
            Glyph {
                x: parent.width - 26
                anchors.verticalCenter: parent.verticalCenter
                visible: field.text !== ""
                name: "clear"
                size: 16
                color: Look.subtitle
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: {
                        field.text = "";
                        toolbar.window.query = "";
                        field.forceActiveFocus();
                    }
                }
            }
        }
    }
    Connections {
        target: toolbar.window
        function onSearchingChanged() {
            if (!toolbar.window.searching)
                field.text = "";
        }
    }

    component Tick: Platform.MenuItem {
        checkable: true
    }
    Platform.Menu {
        id: optionsMenu
        Tick { text: "Sort by Date Edited"; checked: Prefs.sortBy === "edited"; onTriggered: Prefs.sortBy = "edited" }
        Tick { text: "Sort by Date Created"; checked: Prefs.sortBy === "created"; onTriggered: Prefs.sortBy = "created" }
        Tick { text: "Sort by Title"; checked: Prefs.sortBy === "title"; onTriggered: Prefs.sortBy = "title" }
        Platform.MenuSeparator {}
        Tick { text: "Group Notes by Date"; checked: Prefs.grouped; enabled: Prefs.sortBy !== "title"; onTriggered: Prefs.grouped = !Prefs.grouped }
    }
    Platform.Menu {
        id: moreMenu
        Platform.MenuItem {
            visible: !toolbar.window.inDeleted
            text: toolbar.window.open?.pinned ? "Unpin Note" : "Pin Note"
            onTriggered: toolbar.window.togglePin(toolbar.window.chosen)
        }
        Platform.MenuItem { visible: toolbar.window.inDeleted; text: "Recover"; onTriggered: toolbar.window.recover(toolbar.window.chosen) }
        Platform.MenuItem { text: "Export as PDF…"; onTriggered: toolbar.window.exportPdf() }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: toolbar.window.inDeleted ? "Delete Permanently…" : "Delete"; onTriggered: toolbar.window.deleteNote(toolbar.window.chosen) }
    }
}
