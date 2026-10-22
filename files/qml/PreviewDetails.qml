import QtQuick
import Ambrosia

// What Finder's preview lists under an item's name (in the gallery's pane
// and the columns' last): Information, its dates and then what the file's
// header gives (a picture's Dimensions and Resolution), with Show More for
// the rest (the camera, a PDF's pages …); then the item's Tags in a field
// to add more. Placed from the Information heading's baseline, infoBase.
Item {
    id: details

    required property var finder
    required property var item // an ItemInfo
    // [[label, text]]: Created and Modified, as the views write dates.
    property var dates: []
    property real infoBase: 0
    property real textX: Finder.previewPaneTextX
    property real valueRight: Finder.previewPaneValueRight
    property color rule: Finder.previewPaneRule
    property color fieldFill: "transparent"

    readonly property var rows: {
        const out = dates.filter(d => d[1] !== undefined && d[1] !== "").map(d => ({ label: d[0], value: d[1] }));
        for (const d of item.details)
            if (!d.more || finder.previewMore)
                out.push(d);
        return out;
    }
    readonly property bool hasMore: item.details.some(d => d.more)
    // Read once here: the rows' bindings outlive the Finder singleton as
    // the window closes.
    readonly property real rowHeight: Finder.previewPaneRow
    // The baseline of the last row, and how far down the Tags field ends.
    readonly property real lastBase: list.y + list.height - (rowHeight - 15.5)
    implicitHeight: tags.y + tags.height + 12

    QtObject {
        id: headStyle
        readonly property int size: 14
        readonly property int weight: 600
        readonly property real tracking: 0
    }

    Label {
        x: details.textX
        y: details.infoBase - baselineOffset
        style: headStyle
        text: "Information"
    }
    Label {
        visible: details.hasMore
        x: details.width - details.valueRight - width
        y: details.infoBase - baselineOffset
        style: Theme.text.callout
        text: details.finder.previewMore ? "Show Less" : "Show More"
        color: Finder.previewLink
        TapHandler { onTapped: details.finder.previewMore = !details.finder.previewMore }
    }

    // A row a line, its name on the left and its value on the right (more
    // lines when it is long, as a camera's model can be), ruled between.
    Column {
        id: list
        y: details.infoBase + Finder.previewRowFirst - 15.5
        width: details.width
        Repeater {
            model: details.rows
            Item {
                id: row
                required property int index
                required property var modelData
                width: list.width
                height: details.rowHeight + (value.lineCount - 1) * value.implicitHeight / Math.max(1, value.lineCount)

                Label {
                    id: name
                    x: details.textX
                    y: 15.5 - baselineOffset
                    style: Theme.text.callout
                    font.weight: 500
                    text: row.modelData.label
                    color: Theme.color.label.secondary
                }
                Label {
                    id: value
                    readonly property real room: details.width - details.textX - details.valueRight - name.implicitWidth - 12
                    x: details.width - details.valueRight - width
                    y: 15.5 - baselineOffset
                    width: Math.min(implicitWidth, room)
                    style: Theme.text.callout
                    font.weight: 600
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignRight
                    text: row.modelData.value
                }
                Rectangle {
                    visible: row.index < details.rows.length - 1
                    x: details.textX
                    y: row.height - 0.5
                    width: details.width - details.textX - details.valueRight
                    height: 1
                    color: details.rule
                }
            }
        }
    }

    Label {
        id: tagsHead
        x: details.textX
        y: details.lastBase + Finder.previewTagsGap - baselineOffset
        style: headStyle
        text: "Tags"
    }
    TagField {
        id: tags
        x: details.textX
        y: details.lastBase + Finder.previewTagsGap + Finder.previewFieldTop
        width: details.width - details.textX - details.valueRight + 1
        height: Finder.previewField
        item: details.item
        ruled: false
        color: details.fieldFill
        inset: 1
        textTop: 1
        placeholderSize: 12
        placeholderColor: Theme.color.label.tertiary
    }
}
