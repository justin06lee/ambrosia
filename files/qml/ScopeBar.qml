import QtQuick
import Ambrosia

// Under the toolbar while searching, Finder's two rows: where to search
// ("Search: Home “Folder”", the chosen one on a pill) and the Kind
// criterion ("Kind is Any").
Item {
    id: bar

    required property var finder
    readonly property bool hasFolder: finder.searchFolder.toString().startsWith("file:")
    readonly property string folderName: {
        const s = decodeURIComponent(finder.searchFolder.toString().replace(/\/+$/, ""));
        return s.slice(s.lastIndexOf("/") + 1) || "/";
    }

    height: 2 * Finder.scopeRow

    Rectangle {
        anchors.fill: parent
        color: Finder.content
    }
    Repeater {
        model: [Finder.scopeRow - 1, 2 * Finder.scopeRow - 1]
        Rectangle {
            required property var modelData
            y: modelData
            width: bar.width
            height: 1
            color: Finder.separator
        }
    }

    Row {
        x: Finder.scopeX
        height: Finder.scopeRow
        spacing: 2
        Label {
            anchors.verticalCenter: parent.verticalCenter
            rightPadding: 4
            text: "Search:"
            font.weight: 600
            color: Theme.color.label.secondary
        }
        Repeater {
            model: [
                { scope: "home", name: "Home", shown: true },
                { scope: "folder", name: "“" + bar.folderName + "”", shown: bar.hasFolder },
            ]
            Rectangle {
                id: scope
                required property var modelData
                readonly property bool chosen: bar.finder.searchScope === modelData.scope
                visible: modelData.shown
                anchors.verticalCenter: parent.verticalCenter
                width: name.implicitWidth + 22
                height: Finder.scopePill
                radius: 5
                color: chosen ? Finder.scopePillFill : "transparent"
                Label {
                    id: name
                    anchors.centerIn: parent
                    text: scope.modelData.name
                    font.weight: scope.chosen ? 700 : 600
                    color: scope.chosen ? Theme.color.label.primary : Theme.color.label.secondary
                }
                TapHandler {
                    onTapped: bar.finder.setSearchScope(scope.modelData.scope)
                }
            }
        }
    }

    Row {
        x: Finder.scopeX
        y: Finder.scopeRow
        height: Finder.scopeRow
        spacing: 8
        PopupButton {
            anchors.verticalCenter: parent.verticalCenter
            width: 74
            items: [{ text: "Kind", value: "kind" }]
            current: "kind"
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: "is"
            color: Theme.color.label.secondary
        }
        PopupButton {
            anchors.verticalCenter: parent.verticalCenter
            width: 125
            items: [
                { text: "Any", value: "any" },
                { text: "Application", value: "application" },
                { text: "Archive", value: "archive" },
                { text: "Document", value: "document" },
                { text: "Folder", value: "folder" },
                { text: "Image", value: "image" },
                { text: "Movie", value: "movie" },
                { text: "Music", value: "music" },
                { text: "PDF", value: "pdf" },
                { text: "Presentation", value: "presentation" },
                { text: "Text", value: "text" },
            ]
            current: bar.finder.searchKind
            onChosen: (value) => bar.finder.setSearchKind(value)
        }
    }
}
