import QtQuick
import Ambrosia

// Under another app's Open or Save panel: New Folder where something is
// being saved, the kinds of file the app takes when it names more than
// one, and on the right Cancel and the button that chooses.
Item {
    id: bar

    required property var finder // the FinderWindow, a panel
    readonly property var filters: finder.panel?.filters ?? []
    readonly property bool saving: finder.panelKind !== "open"

    height: Finder.panelBar

    Rectangle {
        width: parent.width
        height: 0.5
        color: Finder.separator
    }

    Row {
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        PushButton {
            visible: bar.saving
            enabled: bar.finder.local
            text: "New Folder"
            onClicked: bar.finder.newFolder()
        }
        PopupButton {
            visible: bar.filters.length > 1
            anchors.verticalCenter: parent.verticalCenter
            items: bar.filters
            current: bar.finder.panelFilter
            onChosen: (value) => bar.finder.panelFilter = value
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        PushButton {
            text: "Cancel"
            width: Math.max(implicitWidth, accept.implicitWidth)
            onClicked: bar.finder.close()
        }
        PushButton {
            id: accept
            primary: true
            text: bar.finder.panelVerb
            width: Math.max(implicitWidth, 64)
            enabled: bar.finder.panelCanChoose
            onClicked: bar.finder.panelChoose()
        }
    }
}
