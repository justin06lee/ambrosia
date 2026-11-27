import QtQuick
import Ambrosia
import ActivityMonitor
import "monitor.mjs" as Monitor

// The toolbar, 52 tall, as Activity Monitor's: the lights, the app's name
// with the view's under it, and from the right the search (a round button
// where there is no room), the five tabs, the views' pop-down, and Quit
// with Inspect in one capsule (gray until a process is chosen).
Item {
    id: toolbar

    required property Window window
    property alias search: field
    readonly property bool roomy: width - Look.titleX - tools.fixed - Look.searchWidth - Look.edge >= 110

    height: Look.toolbar

    TrafficLights {
        x: Look.lightsX
        y: Look.lightsY
        window: toolbar.window
    }

    Label {
        id: title
        x: Look.titleX
        y: 13
        width: Math.max(0, tools.x - x - 12)
        visible: width >= 60
        elide: Text.ElideRight
        text: "Activity Monitor"
        style: Theme.text.headline
        font.weight: 700
        color: toolbar.window.looksActive ? Look.title : Look.titleInactive
    }
    Label {
        visible: title.visible
        x: title.x
        y: 29
        width: title.width
        elide: Text.ElideRight
        text: Monitor.categoryTitle(toolbar.window.category)
        style: Theme.text.footnote
        color: toolbar.window.looksActive ? Look.subtitle : Look.titleInactive
    }

    Row {
        id: tools
        // What stands before the search field, gaps and all.
        readonly property real fixed: Look.actionsWidth + Look.viewsWidth + tabs.width + 3 * Look.gap
        anchors.right: parent.right
        anchors.rightMargin: Look.edge
        y: (Look.toolbar - Look.control) / 2
        spacing: Look.gap

        Capsule {
            width: Look.actionsWidth
            ToolButton {
                window: toolbar.window
                width: Look.actionsWidth / 2
                glyph: "stop"
                usable: toolbar.window.canQuit
                onClicked: toolbar.window.quitSelected()
            }
            ToolButton {
                window: toolbar.window
                width: Look.actionsWidth / 2
                glyph: "info"
                usable: toolbar.window.selected >= 0
                onClicked: toolbar.window.inspectSelected()
            }
        }
        Capsule {
            id: views
            width: Look.viewsWidth
            Item {
                width: Look.viewsWidth
                height: Look.control
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 6
                    height: 28
                    radius: height / 2
                    color: Look.pressed
                    visible: viewsArea.pressed || viewsMenu.visible
                }
                Glyph {
                    x: 7
                    anchors.verticalCenter: parent.verticalCenter
                    name: "more"
                    size: 19
                    color: toolbar.window.looksActive ? Look.glyph : Look.glyphInactive
                }
                Glyph {
                    x: 28
                    anchors.verticalCenter: parent.verticalCenter
                    name: "chevronDown"
                    size: 10
                    color: toolbar.window.looksActive ? Look.glyph : Look.glyphInactive
                }
                MouseArea {
                    id: viewsArea
                    anchors.fill: parent
                    onPressed: viewsMenu.openUnder(views)
                }
            }
        }
        Tabs {
            id: tabs
            window: toolbar.window
        }
        SearchField {
            id: field
            window: toolbar.window
            collapsed: !toolbar.roomy && !editing && text === ""
            width: collapsed ? Look.control : Math.min(Look.searchWidth, Math.max(120, toolbar.width - Look.titleX - tools.fixed - Look.edge))
            onDismissed: toolbar.window.takeKeys()
            onNext: toolbar.window.takeKeys()
        }
    }
    PopupMenu {
        id: viewsMenu
        items: Monitor.categories.map(category => ({ text: category.title, value: category.key }))
        current: toolbar.window.category
        onChosen: (value) => toolbar.window.view(value)
        onClosed: toolbar.window.takeKeys()
    }
}
