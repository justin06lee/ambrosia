import QtQuick
import Ambrosia

// Finder's toolbar: back and forward, the folder's name, then on the right
// the view switcher, Group, Share/Tags/More and Search, each a glass capsule.
Item {
    id: toolbar

    required property var finder // the FinderWindow

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
        width: viewSwitcher.x - x - 8
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: toolbar.finder.title
        style: Theme.text.title3
        color: toolbar.finder.active ? Theme.color.label.primary : Theme.color.label.tertiary
    }

    Capsule {
        id: viewSwitcher
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

    Capsule {
        id: group
        x: share.x - Finder.capsuleGap - width
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
        x: search.x - Finder.searchGap + 1 - width
        y: Finder.toolbarTop
        ToolButton { glyph: "share"; enabled_: toolbar.finder.hasSelection }
        ToolButton { glyph: "tag"; enabled_: toolbar.finder.hasSelection }
        ToolButton { glyph: "more" }
    }

    Capsule {
        id: search
        x: toolbar.width - Finder.toolbarTop - width
        y: Finder.toolbarTop
        width: Finder.control
        ToolButton { glyph: "search"; glyphSize: 21 }
    }
}
