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
                                onPressed: (mouse) => {
                                    sidebar.window.choose(row.modelData.key);
                                    if (mouse.button === Qt.RightButton)
                                        menu.open();
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
                                x: Look.sidebarTextX + row.indent
                                width: parent.width - x - (row.modelData.eject ? 40 : 16)
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: row.modelData.name
                                font.weight: row.chosen ? 600 : 500
                                color: row.ink
                            }
                            Item {
                                visible: row.modelData.eject
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
        Platform.MenuItem { text: "Show in Files"; enabled: sidebar.window.item?.mounted ?? false; onTriggered: sidebar.window.reveal() }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: sidebar.window.may.mountLabel; enabled: sidebar.window.may.mount; onTriggered: sidebar.window.toggleMount() }
        Platform.MenuItem { text: "Eject"; enabled: sidebar.window.may.eject; onTriggered: sidebar.window.eject(sidebar.window.chosen) }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: "Run First Aid…"; enabled: sidebar.window.may.firstAid; onTriggered: sidebar.window.askFirstAid() }
        Platform.MenuItem { text: "Erase…"; enabled: sidebar.window.may.erase; onTriggered: sidebar.window.askErase() }
    }
}
