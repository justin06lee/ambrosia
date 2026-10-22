import QtQuick
import Ambrosia

// The preview pane on the right of the gallery view (View > Show Preview,
// ⇧⌘P): the item selected, its name, kind and size, then its Information
// (dates, a picture's Dimensions and Resolution, Show More) and Tags, and
// the quick actions at the foot. Placed on Finder's measurements, from the
// window's top.
Item {
    id: preview

    required property var finder
    readonly property var info: finder.shownInfo
    readonly property bool one: finder.selectedCount === 1
    // Read again whenever the selection is set again, as after a rename.
    readonly property var times: finder.shownRow >= 0 && finder.selected ? finder.model.timesAt(finder.shownRow) : ({})
    readonly property var dates: [["Created", times.created], ["Modified", times.modified]]
    // Only while the pane shows: hidden, its field would take the keyboard
    // from the view's own and close it.
    readonly property bool renaming: finder.previewShown && one && finder.renaming && finder.editing.toString() === (info.url ?? "").toString()

    QtObject {
        id: nameStyle
        readonly property int size: 16
        readonly property int weight: 600
        readonly property real tracking: 0
    }
    ItemInfo {
        id: fileInfo
        url: preview.one ? preview.info.url ?? "" : ""
    }

    // The pane's grey, square but for the window's corner; below it, under
    // where Finder has More…, the window's own color.
    Rectangle {
        y: 0.5 // inside the window's rim
        width: parent.width - 0.5
        height: parent.height - Finder.previewPaneFoot - y
        radius: Finder.windowRadius - 0.5
        color: Finder.previewPaneFill
        Rectangle { width: parent.radius; height: parent.height; color: parent.color }
        Rectangle { y: parent.radius; width: parent.width; height: parent.height - y; color: parent.color }
    }

    Item {
        visible: preview.info.url !== undefined
        anchors.fill: parent

        Thumbnail {
            x: Finder.previewPaneIconX
            y: Finder.previewPaneIconY
            width: Finder.previewPaneIcon
            height: Finder.previewPaneIcon
            url: preview.info.url ?? ""
            source: preview.info.thumb ?? ""
            isDir: preview.info.isDir ?? false
            badge: preview.info.badge ?? ""
            tint: preview.info.isDir && preview.info.tags?.length > 0 ? preview.info.tags[0] : ""
        }
        Label {
            id: name
            visible: !preview.renaming
            x: Finder.previewPaneNameX
            y: Finder.previewPaneNameBase - baselineOffset
            width: preview.width - x - 12
            style: nameStyle
            text: preview.one ? preview.info.name ?? "" : preview.finder.selectedCount + " items"
            elide: Text.ElideMiddle
        }
        Loader {
            active: preview.renaming
            x: name.x - 5
            y: name.y - 2
            width: Math.min(item ? item.implicitWidth : 0, preview.width - x - 8)
            sourceComponent: RenameField {
                finder: preview.finder
                name: preview.info.name ?? ""
                isDir: preview.info.isDir ?? false
                style: nameStyle
            }
        }
        Label {
            visible: preview.one
            x: Finder.previewPaneNameX
            y: Finder.previewPaneKindBase - baselineOffset
            width: preview.width - x - 12
            font.pixelSize: 14
            text: [preview.info.kind, preview.info.sizeText].filter(s => s && s !== "--").join(" - ")
            elide: Text.ElideRight
            color: Theme.color.label.secondary
        }

        PreviewDetails {
            visible: preview.one
            width: parent.width
            finder: preview.finder
            item: fileInfo
            infoBase: Finder.previewPaneInfoBase
            dates: preview.dates
            fieldFill: Finder.content
        }
        QuickActions {
            visible: preview.one
            y: parent.height - Finder.previewPaneFoot
            width: parent.width
            name: preview.info.name ?? ""
            picture: fileInfo.preview === "image"
        }
    }
}
