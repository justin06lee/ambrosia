import QtQuick
import Qt.labs.platform as Platform
import Ambrosia
import FontBook
import "fontbook.mjs" as Book

// The sidebar, 150 wide, flush and as tall as the window: the places
// fonts are listed from under their headings (fontbook.mjs sections). The
// chosen one stands on a rounded fill. A collection is renamed in place
// and has a menu of its own.
Item {
    id: sidebar

    required property var window
    readonly property var parts: Book.sections(Library.languages, window.collections)

    width: Look.sidebarWidth

    Rectangle {
        anchors.fill: parent
        topLeftRadius: sidebar.window.corner
        bottomLeftRadius: sidebar.window.corner
        color: Look.sidebarFill
    }
    Rectangle {
        x: parent.width - 1
        width: 1
        height: parent.height
        color: Look.sidebarRule
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
        y: Look.sidebarTop
        width: parent.width - 1
        height: parent.height - y
        contentHeight: column.height + 12
        clip: true
        boundsBehavior: Flickable.StopAtBounds

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
                            x: 14.5
                            y: 22 - height / 2
                            text: part.modelData.title
                            style: Theme.text.footnote
                            font.weight: 600
                            color: sidebar.window.looksActive ? Look.sidebarHeading : Look.sidebarHeadingInactive
                        }
                    }
                    Repeater {
                        model: part.modelData.items

                        Item {
                            id: row
                            required property var modelData
                            readonly property bool chosen: sidebar.window.section === modelData.key
                            readonly property bool renaming: modelData.collection !== undefined && sidebar.window.renaming === modelData.collection
                            readonly property color ink: sidebar.window.looksActive ? Look.sidebarText : Look.sidebarTextInactive
                            width: column.width
                            height: Look.sidebarRow

                            Rectangle {
                                visible: row.chosen
                                x: Look.sidebarInset
                                width: parent.width - 2 * Look.sidebarInset + 1
                                height: parent.height
                                radius: 8
                                color: sidebar.window.looksActive ? Look.sidebarChosen : Look.sidebarChosenInactive
                            }
                            Glyph {
                                x: Look.sidebarGlyphX - 3
                                anchors.verticalCenter: parent.verticalCenter
                                name: row.modelData.badge !== undefined ? "badge" : row.modelData.glyph
                                size: 19
                                color: sidebar.window.looksActive ? (Look.dark ? "#b9b6b5" : "#6a6a6a") : Look.sidebarTextInactive
                            }
                            Text {
                                visible: row.modelData.badge !== undefined
                                x: Look.sidebarGlyphX - 3
                                width: 19
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: row.modelData.badge ?? ""
                                font.family: Theme.uiFont
                                font.pixelSize: 7
                                font.weight: 700
                                color: sidebar.window.looksActive ? (Look.dark ? "#b9b6b5" : "#6a6a6a") : Look.sidebarTextInactive
                            }
                            Label {
                                visible: !row.renaming
                                x: Look.sidebarTextX
                                width: parent.width - x - 14
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: row.modelData.title
                                font.weight: row.chosen ? 600 : 500
                                color: row.ink
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onPressed: (mouse) => {
                                    sidebar.window.go(row.modelData.key);
                                    if (mouse.button === Qt.RightButton && row.modelData.collection !== undefined) {
                                        menu.collection = row.modelData.collection;
                                        menu.open();
                                    }
                                }
                                onDoubleClicked: if (row.modelData.collection !== undefined) sidebar.window.renaming = row.modelData.collection
                            }
                            // The collection's name, being typed.
                            Rectangle {
                                visible: row.renaming
                                x: Look.sidebarTextX - 5
                                width: parent.width - x - 14
                                height: 22
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 4
                                color: Look.ground
                                border.width: 2
                                border.color: Theme.accent.bg
                                TextInput {
                                    id: nameField
                                    x: 5
                                    width: parent.width - 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    clip: true
                                    font.family: Theme.uiFont
                                    font.pixelSize: Theme.text.body.size
                                    color: Theme.color.label.primary
                                    selectionColor: Theme.accent.highlight
                                    selectedTextColor: Theme.color.label.primary
                                    renderType: Text.NativeRendering
                                    selectByMouse: true
                                    onVisibleChanged: {
                                        if (visible) {
                                            text = row.modelData.collection;
                                            forceActiveFocus();
                                            selectAll();
                                        }
                                    }
                                    onAccepted: sidebar.window.finishRenaming(row.modelData.collection, text)
                                    onActiveFocusChanged: if (!activeFocus && row.renaming) sidebar.window.finishRenaming(row.modelData.collection, text)
                                    Keys.onEscapePressed: sidebar.window.finishRenaming(row.modelData.collection, row.modelData.collection)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Platform.Menu {
        id: menu
        property string collection
        Platform.MenuItem { text: "Rename “" + menu.collection + "”"; onTriggered: sidebar.window.renaming = menu.collection }
        Platform.MenuItem { text: "Delete “" + menu.collection + "”"; onTriggered: sidebar.window.deleteCollection(menu.collection) }
    }
}
