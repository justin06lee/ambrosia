import QtQuick
import Ambrosia
import Files

// The path bar along the window's bottom: each folder from the computer down
// to this one, separated by chevrons; a click goes there.
Item {
    id: bar

    required property var finder

    height: Finder.pathBar

    // [{name, url}] from the root down.
    readonly property var crumbs: {
        const url = finder.url;
        if (url.toString().indexOf("file://") !== 0)
            return [{ name: finder.title, url: url }];
        const parts = decodeURIComponent(url.toString().slice(7)).split("/").filter(p => p.length > 0);
        const list = [{ name: Places.computer, url: "file:///", root: true }];
        let path = "";
        for (const part of parts) {
            path += "/" + part;
            list.push({ name: part, url: "file://" + path });
        }
        return list;
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Finder.separator
    }

    Row {
        x: 13
        height: parent.height
        spacing: 3
        Repeater {
            model: bar.crumbs
            Row {
                id: crumb
                required property var modelData
                required property int index
                height: bar.height
                spacing: 3
                Glyph {
                    visible: crumb.index > 0
                    anchors.verticalCenter: parent.verticalCenter
                    name: "pathSeparator"
                    size: 12
                    color: Theme.color.label.secondary
                }
                Glyph {
                    visible: crumb.modelData.root === true
                    anchors.verticalCenter: parent.verticalCenter
                    name: "drive"
                    size: 14
                    color: Theme.color.label.secondary
                }
                FileIcon {
                    visible: crumb.modelData.root !== true
                    anchors.verticalCenter: parent.verticalCenter
                    size: 14
                    kind: "folder"
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: crumb.modelData.name
                    style: Theme.text.callout
                    color: drop.containsDrag ? Theme.accent.bg : Theme.color.label.secondary
                    TapHandler { onTapped: bar.finder.go(crumb.modelData.url) }
                    // Each folder takes drops, as Finder's path bar does.
                    DropArea {
                        id: drop
                        anchors.fill: parent
                        anchors.margins: -4
                        enabled: crumb.modelData.url.toString().startsWith("file:///") && crumb.modelData.url.toString() !== "file:///"
                        keys: ["text/uri-list"]
                        onEntered: (drag) => drag.accept(Qt.MoveAction)
                        onDropped: (drop) => drop.accept(bar.finder.dropOn(drop.urls, Qt.url(crumb.modelData.url)))
                    }
                }
            }
        }
    }
}
