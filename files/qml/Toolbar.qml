import QtQuick
import Ambrosia

// Finder's toolbar: back and forward, the folder's name, then on the right
// the view switcher, Group, Share/Tags/More and Search, each a glass capsule.
// While searching, the search button is a field and the rest close up as
// Finder's do: the views behind one button, Tags and More behind ».
Item {
    id: toolbar

    required property var finder // the FinderWindow
    readonly property bool compact: finder.searchOpen
    function focusSearch() {
        if (search.item && search.item.focusField)
            search.item.focusField();
    }

    height: Finder.control + Finder.toolbarTop

    Capsule {
        id: nav
        y: Finder.toolbarTop
        width: Finder.navWidth
        ToolButton {
            glyph: "back"
            glyphSize: 22
            pillWidth: 30
            enabled_: toolbar.finder.canGoBack
            onClicked: toolbar.finder.back()
        }
        Rectangle {
            width: 0.5
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Finder.separator
        }
        ToolButton {
            glyph: "forward"
            glyphSize: 22
            pillWidth: 30
            enabled_: toolbar.finder.canGoForward
            onClicked: toolbar.finder.forward()
        }
    }

    Label {
        x: nav.width + Finder.titleGap
        y: Finder.toolbarTop
        height: Finder.control
        width: (toolbar.compact ? viewButton.x : viewSwitcher.x) - x - 8
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: toolbar.finder.title
        style: Theme.text.title3
        color: toolbar.finder.looksActive ? Theme.color.label.primary : Theme.color.label.tertiary
    }

    Capsule {
        id: viewSwitcher
        visible: !toolbar.compact
        x: group.x - Finder.capsuleGap + 1 - width
        y: Finder.toolbarTop
        padding: 2
        Repeater {
            model: [["icon", "viewIcons"], ["list", "viewList"], ["column", "viewColumns"], ["gallery", "viewGallery"]]
            ToolButton {
                required property var modelData
                glyph: modelData[1]
                selected: toolbar.finder.view === modelData[0]
                onClicked: toolbar.finder.view = modelData[0]
            }
        }
    }

    // The views, as one button while the toolbar is compact.
    readonly property var views: [
        { value: "icon", text: "as Icons", glyph: "viewIcons" },
        { value: "list", text: "as List", glyph: "viewList" },
        { value: "column", text: "as Columns", glyph: "viewColumns" },
        { value: "gallery", text: "as Gallery", glyph: "viewGallery" },
    ]
    Capsule {
        id: viewButton
        visible: toolbar.compact
        x: group.x - 17 - width
        y: Finder.toolbarTop
        width: Finder.groupWidth
        ToolButton {
            width: 30
            glyph: toolbar.views.find(v => v.value === toolbar.finder.view)?.glyph ?? "viewList"
            onClicked: viewMenu.openOver(viewButton)
        }
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            name: "chevronUpDown"
            size: 12
            color: Theme.color.label.primary
        }
        PopupMenu {
            id: viewMenu
            items: toolbar.views
            current: toolbar.finder.view
            onChosen: (value) => toolbar.finder.view = value
        }
    }

    Capsule {
        id: group
        x: share.x - (toolbar.compact ? 15 : Finder.capsuleGap) - width
        y: Finder.toolbarTop
        width: Finder.groupWidth
        ToolButton {
            width: 30
            glyph: "group"
            glyphSize: 18
        }
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            name: "chevronDown"
            size: 12
            color: Theme.color.label.primary
        }
    }

    Capsule {
        id: share
        x: (toolbar.compact ? overflow.x - 33 : search.x - Finder.searchGap + 1) - width
        y: Finder.toolbarTop
        ToolButton { glyph: "share"; enabled_: toolbar.finder.hasSelection }
        ToolButton { visible: !toolbar.compact; glyph: "tag"; enabled_: toolbar.finder.hasSelection }
        ToolButton { visible: !toolbar.compact; glyph: "more" }
    }

    // What doesn't fit beside the search field.
    Capsule {
        id: overflow
        visible: toolbar.compact
        x: search.x - 8 - width
        y: Finder.toolbarTop
        width: Finder.control
        ToolButton {
            glyph: "overflow"
            glyphSize: 18
            onClicked: overflowMenu.openOver(overflow)
        }
        PopupMenu {
            id: overflowMenu
            items: [{ text: "Tags…", value: "tags", enabled: toolbar.finder.hasSelection }]
            onChosen: (value) => toolbar.finder.getInfo()
        }
    }

    Loader {
        id: search
        x: toolbar.width - Finder.toolbarTop - width
        y: Finder.toolbarTop
        width: toolbar.compact ? Finder.searchField : Finder.control
        height: Finder.control
        sourceComponent: toolbar.compact ? searchField : searchButton
    }
    Component {
        id: searchButton
        Capsule {
            ToolButton {
                glyph: "search"
                glyphSize: 21
                onClicked: toolbar.finder.openSearch()
            }
        }
    }
    Component {
        id: searchField
        SearchField {
            finder: toolbar.finder
            Component.onCompleted: focusField()
        }
    }
}
