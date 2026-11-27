import QtQuick
import Qt.labs.platform as Platform
import Ambrosia
import FontBook
import "fontbook.mjs" as Book

// The toolbar, 52 tall, as Font Book's: the lights and the sidebar's
// button over the sidebar; the place's name with how many typefaces it
// holds; from the right the search, the size slider with the info button,
// and the views. On a typeface's page: a button back, its name, its
// styles' pop-up, and the page's two views.
Item {
    id: toolbar

    required property var window
    property alias search: field
    readonly property bool page: window.opened !== ""
    // Where the part over the views begins.
    readonly property real start: window.sidebarShown ? Look.sidebarWidth : 0
    readonly property real titleX: back.visible ? back.x + Look.control + 12 : Math.max(start + Look.titleAfterSidebar, Look.sidebarButtonX + Look.control + 12)
    readonly property bool roomy: width - titleX - tools.fixed - Look.searchWidth - Look.edge >= 120

    height: Look.toolbar

    TrafficLights {
        x: Look.lightsX
        y: Look.lightsY
        window: toolbar.window
    }
    Capsule {
        x: Look.sidebarButtonX
        y: (Look.toolbar - Look.control) / 2
        width: Look.control
        ToolButton {
            window: toolbar.window
            glyph: "sidebar"
            glyphSize: 20
            onClicked: toolbar.window.sidebarShown = !toolbar.window.sidebarShown
        }
    }
    Capsule {
        id: back
        visible: toolbar.page
        x: Math.max(toolbar.start + 8, Look.sidebarButtonX + Look.control + 8)
        y: (Look.toolbar - Look.control) / 2
        width: Look.control
        ToolButton {
            window: toolbar.window
            glyph: "chevronLeft"
            glyphSize: 18
            onClicked: toolbar.window.back()
        }
    }

    Label {
        id: title
        x: toolbar.titleX
        y: 11
        width: Math.max(0, tools.x - x - 12)
        visible: width >= 60
        elide: Text.ElideRight
        text: toolbar.page ? toolbar.window.opened : Book.sectionTitle(toolbar.window.section, Library.languages)
        style: Theme.text.headline
        font.weight: 700
        color: toolbar.window.looksActive ? Look.title : Look.titleInactive
    }
    Label {
        visible: title.visible
        x: title.x
        y: 27
        width: title.width
        elide: Text.ElideRight
        text: toolbar.page ? Book.stylesText(toolbar.window.openedFamily?.styles.length ?? 0) : Book.typefacesText(toolbar.window.listedFamilies.length)
        style: Theme.text.footnote
        color: toolbar.window.looksActive ? Look.subtitle : Look.titleInactive
    }

    Row {
        id: tools
        // What stands before the search field, gaps and all.
        readonly property real fixed: Look.sizeWidth + views.width + 2 * Look.gap + (styles.visible ? styles.width + Look.gap : 0)
        anchors.right: parent.right
        anchors.rightMargin: Look.edge
        y: (Look.toolbar - Look.control) / 2
        spacing: Look.gap

        // The page's styles: the one shown, and a menu of them all.
        Capsule {
            id: styles
            visible: toolbar.page
            width: Look.stylesWidth
            Item {
                width: Look.stylesWidth
                height: Look.control
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width - 6
                    height: 28
                    radius: 14
                    color: Look.pressed
                    visible: stylesArea.pressed
                }
                Label {
                    x: 14
                    width: parent.width - 14 - 26
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: toolbar.window.openedFamily?.styles[toolbar.window.openedStyle]?.name ?? ""
                    font.weight: 500
                    color: toolbar.window.looksActive ? Look.glyph : Look.glyphInactive
                }
                Glyph {
                    x: parent.width - 23
                    anchors.verticalCenter: parent.verticalCenter
                    name: "chevronUpDown"
                    size: 13
                    color: toolbar.window.looksActive ? Look.subtitle : Look.glyphInactive
                }
                // The menu drops under the capsule: over it, a style far
                // down the list would leave the menu scrolled (it can't
                // reach above the window on Wayland).
                Item { id: stylesUnder; y: Look.control + 4; width: 1; height: 1 }
                MouseArea {
                    id: stylesArea
                    anchors.fill: parent
                    onClicked: stylesMenu.open(stylesUnder)
                }
            }
        }
        Segments {
            id: views
            window: toolbar.window
            items: toolbar.page ? [{ key: "specimen", glyph: "viewSpecimen" }, { key: "samples", glyph: "viewSamples" }]
                                : [{ key: "grid", glyph: "viewGrid" }, { key: "samples", glyph: "viewSamples" }, { key: "list", glyph: "viewList" }]
            current: toolbar.page ? toolbar.window.pageMode : toolbar.window.view
            onChosen: (key) => {
                if (toolbar.page)
                    toolbar.window.pageMode = key;
                else
                    toolbar.window.view = key;
                toolbar.window.takeKeys();
            }
        }
        Capsule {
            width: Look.sizeWidth
            SizeSlider {
                window: toolbar.window
                value: toolbar.window.size
                onMoved: (value) => toolbar.window.setSize(value)
            }
            Item {
                width: Look.sizeWidth - 117
                height: Look.control
                Rectangle {
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    radius: 14
                    color: toolbar.window.infoShown ? Look.segmentChosen : Look.pressed
                    visible: toolbar.window.infoShown || infoArea.pressed
                }
                Glyph {
                    anchors.centerIn: parent
                    name: "info"
                    size: 19
                    color: toolbar.window.looksActive ? Look.glyph : Look.glyphInactive
                }
                MouseArea {
                    id: infoArea
                    anchors.fill: parent
                    onClicked: toolbar.window.infoShown = !toolbar.window.infoShown
                }
            }
        }
        SearchField {
            id: field
            window: toolbar.window
            // A typeface's page has only the round button, as a Mac's.
            collapsed: (toolbar.page || !toolbar.roomy) && !editing && text === ""
            width: collapsed ? Look.control : Math.min(Look.searchWidth, Math.max(120, toolbar.width - toolbar.titleX - tools.fixed - Look.edge - 80))
            onDismissed: toolbar.window.takeKeys()
            onNext: toolbar.window.takeKeys()
        }
    }

    Platform.Menu {
        id: stylesMenu
        Instantiator {
            model: toolbar.window.openedFamily?.styles ?? []
            delegate: Platform.MenuItem {
                required property var modelData
                required property int index
                text: modelData.name
                checkable: true
                checked: index === toolbar.window.openedStyle
                onTriggered: toolbar.window.openedStyle = index
            }
            onObjectAdded: (index, object) => stylesMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => stylesMenu.removeItem(object)
        }
    }
}
