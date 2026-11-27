import QtQuick
import Ambrosia
import Preview

// The toolbar, 52 tall, as Preview's: the lights, the sidebar's pop-down
// (at the sidebar's edge while it shows), the file's name with what page is
// in view under it, and from the right the search (a PDF's; a round button
// until there is room or it is used), Rotate Left, and Zoom Out, Actual
// Size and Zoom In in one capsule. What a Mac's has and this doesn't yet
// (highlighting, Markup, the inspector, Share) is left out, not drawn dead.
Item {
    id: toolbar

    required property Window window
    readonly property var view: window.view
    readonly property real side: window.sidebarShown ? Look.sidebarWidth : 0
    readonly property bool ready: view !== null && window.showsDocument
    property alias search: field

    // The search field is whole when the title keeps 150 beside it, or
    // while it is being used.
    readonly property real titleLeft: window.sidebarShown ? side + Look.titleAfterSidebar : Look.titleX
    readonly property real toolsNarrow: Look.zoomWidth + Look.control + (window.pdf ? Look.control + Look.gap : 0) + 2 * Look.gap
    readonly property bool roomy: width - titleLeft - toolsNarrow - (Look.searchWidth - Look.control) >= 150
    readonly property bool searchWide: roomy || field.editing || field.text !== ""

    height: Look.toolbar

    TrafficLights {
        x: Look.lightsX
        y: Look.lightsY
        window: toolbar.window
    }

    Capsule {
        id: sidebarButton
        x: toolbar.window.sidebarShown ? Look.sidebarWidth - Look.gap - width : Look.sidebarButtonX
        y: (Look.toolbar - Look.control) / 2
        width: Look.sidebarButtonWidth

        Item {
            width: Look.sidebarButtonWidth
            height: Look.control
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 6
                height: 28
                radius: height / 2
                color: Look.pressed
                visible: sidebarArea.pressed || sidebarMenu.visible
            }
            Glyph {
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                name: "sidebar"
                size: 19
                color: !toolbar.ready ? Look.glyphOff : toolbar.window.looksActive ? Look.glyph : Look.glyphInactive
            }
            Glyph {
                x: 31
                anchors.verticalCenter: parent.verticalCenter
                name: "chevronDown"
                size: 10
                color: !toolbar.ready ? Look.glyphOff : toolbar.window.looksActive ? Look.glyph : Look.glyphInactive
            }
            MouseArea {
                id: sidebarArea
                anchors.fill: parent
                enabled: toolbar.ready
                onPressed: sidebarMenu.openUnder(sidebarButton)
            }
        }
    }
    PopupMenu {
        id: sidebarMenu
        items: [{ text: "Hide Sidebar", value: "none" }, { text: "Thumbnails", value: "thumbnails" }]
            .concat(toolbar.window.pdf ? [{ text: "Table of Contents", value: "outline", enabled: toolbar.window.doc.outline.length > 0 }] : [])
        current: toolbar.window.sidebarMode
        onChosen: (value) => toolbar.window.sidebarMode = value
        onClosed: toolbar.window.takeKeys()
    }

    Label {
        id: title
        x: toolbar.titleLeft
        y: subtitle.visible ? 13 : (Look.toolbar - height) / 2
        width: Math.max(0, tools.x - x - 12)
        elide: Text.ElideMiddle
        text: toolbar.window.name
        style: Theme.text.headline
        font.weight: 700
        color: toolbar.window.looksActive ? Look.title : Look.titleInactive
    }
    Label {
        id: subtitle
        visible: text !== ""
        x: title.x
        y: 29
        width: title.width
        elide: Text.ElideRight
        text: toolbar.window.subtitle
        style: Theme.text.footnote
        color: toolbar.window.looksActive ? Look.subtitle : Look.titleInactive
    }

    Row {
        id: tools
        anchors.right: parent.right
        anchors.rightMargin: Look.gap
        y: (Look.toolbar - Look.control) / 2
        spacing: Look.gap

        Capsule {
            width: Look.zoomWidth
            Repeater {
                model: [
                    { glyph: "zoomOut", act: () => toolbar.view.zoomOut(), can: () => toolbar.view.zoom > toolbar.view.least + 1e-6 },
                    { glyph: "zoomActual", act: () => toolbar.view.actualSize(), can: () => true },
                    { glyph: "zoomIn", act: () => toolbar.view.zoomIn(), can: () => toolbar.view.zoom < toolbar.view.most - 1e-6 },
                ]
                ToolButton {
                    required property var modelData
                    required property int index
                    window: toolbar.window
                    width: Look.zoomWidth / 3
                    glyph: modelData.glyph
                    usable: toolbar.ready && modelData.can()
                    onClicked: modelData.act()

                    // Between it and the one before.
                    Rectangle {
                        visible: parent.index > 0
                        x: -0.5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 18
                        color: Look.capsuleDivider
                    }
                }
            }
        }
        Capsule {
            width: Look.control
            ToolButton {
                window: toolbar.window
                glyph: "rotateLeft"
                usable: toolbar.ready
                onClicked: toolbar.view.rotate(-1)
            }
        }
        SearchField {
            id: field
            visible: toolbar.window.pdf
            window: toolbar.window
            collapsed: !toolbar.searchWide
            enabled: toolbar.ready
            width: collapsed ? Look.control : Look.searchWidth
            note: toolbar.window.doc.matchCount > 0 ? (toolbar.view?.currentMatch ?? -1) + 1 + " of " + toolbar.window.doc.matchCount
                : toolbar.window.doc.searching || toolbar.window.doc.find === "" ? "" : "Not found"
            onNext: (direction) => toolbar.view.findNext(direction)
            onDismissed: toolbar.window.takeKeys()
        }
    }
}
