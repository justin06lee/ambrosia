import QtQuick
import Ambrosia
import DiskUtility

// What is chosen, as Disk Utility shows it (Look.qml): its picture, name
// and the lines under it, its capacity in a box, a bar of what is on it
// with a legend, and a table of two columns. The words are disks.mjs's
// (page()).
Item {
    id: page

    required property var window
    // { title, subtitle, third, icon, capacity, caption, bar, left, right }
    property var told: null
    readonly property real inner: width - 2 * Look.pad
    readonly property var parts: told?.bar ?? []
    readonly property real barWidth: inner - Look.barInsetLeft - Look.barInsetRight
    readonly property real total: parts.reduce((sum, part) => sum + part.bytes, 0)
    readonly property int legendRows: Math.max(1, Math.ceil(parts.length / perRow))
    readonly property int perRow: Math.max(1, Math.floor((inner + 12) / Look.legendColumn))
    readonly property real tableY: Look.legendY + (legendRows - 1) * Look.legendRow + Look.tableAfterLegend
    readonly property int rows: Math.max(told?.left.length ?? 0, told?.right.length ?? 0)

    visible: told !== null

    DiskIcon {
        x: Look.pad
        y: Look.iconY
        kind: page.told?.icon ?? "internal"
    }
    Label {
        id: title
        x: Look.titleX
        y: Look.titleBase - baselineOffset
        width: Math.max(0, box.x - x - 16)
        elide: Text.ElideRight
        text: page.told?.title ?? ""
        font.pixelSize: 24
        font.weight: 700
        font.letterSpacing: -0.2
        color: Look.text
    }
    Label {
        x: Look.titleX
        y: Look.subtitleBase - baselineOffset
        width: title.width
        elide: Text.ElideRight
        text: page.told?.subtitle ?? ""
        font.pixelSize: 13
        color: Look.note
    }
    Label {
        x: Look.titleX
        y: Look.thirdBase - baselineOffset
        width: title.width
        elide: Text.ElideRight
        text: page.told?.third ?? ""
        font.pixelSize: 11
        color: Look.note
    }

    // The capacity, in its box.
    Rectangle {
        id: box
        x: page.width - Look.pad - width
        y: Look.boxY
        width: Look.boxWidth
        height: Look.boxHeight
        radius: 4
        color: "transparent"
        border.width: 1
        border.color: Look.boxRim
        Label {
            anchors.centerIn: parent
            text: page.told?.capacity ?? ""
            font.pixelSize: 17
            color: Look.note
        }
    }
    Label {
        visible: text !== ""
        x: box.x
        y: box.y + box.height + 5
        width: box.width
        horizontalAlignment: Text.AlignHCenter
        text: page.told?.caption ?? ""
        font.pixelSize: 9
        font.weight: 500
        font.capitalization: Font.AllUppercase
        color: Look.note
    }

    Rectangle {
        x: Look.pad
        y: Look.ruleY
        width: page.inner
        height: 1
        color: Look.rule
    }

    // The bar: each part as wide as its share, none too thin to see; the
    // first and last take the bar's round ends.
    Item {
        id: bar
        x: Look.pad + Look.barInsetLeft
        y: Look.barY
        width: page.barWidth
        height: Look.barHeight

        // Each part's width: its share, but at least 8, the rest shrunk to
        // make room.
        readonly property var widths: {
            const parts = page.parts;
            if (parts.length === 0 || !(page.total > 0))
                return parts.map(() => width / Math.max(1, parts.length));
            const least = 8;
            let widths = parts.map(part => part.bytes > 0 ? Math.max(least, width * part.bytes / page.total) : 0);
            const over = widths.reduce((sum, w) => sum + w, 0) - width;
            if (over > 0) {
                const roomy = widths.reduce((sum, w) => sum + (w > least ? w - least : 0), 0);
                widths = widths.map(w => w > least && roomy > 0 ? w - over * (w - least) / roomy : w);
            }
            return widths;
        }
        Repeater {
            model: page.parts
            Rectangle {
                required property var modelData
                required property int index
                readonly property bool first: bar.widths.slice(0, index).every(w => w === 0)
                readonly property bool last: bar.widths.slice(index + 1).every(w => w === 0)
                x: bar.widths.slice(0, index).reduce((sum, w) => sum + w, 0)
                width: bar.widths[index] ?? 0
                height: bar.height
                visible: width > 0
                topLeftRadius: first ? 5 : 0
                bottomLeftRadius: first ? 5 : 0
                topRightRadius: last ? 5 : 0
                bottomRightRadius: last ? 5 : 0
                color: Look.partFill(modelData.color)
                border.width: 1
                border.color: Look.partLine(modelData.color)
            }
        }
    }

    // The legend: a square of each part's color, its name, its size.
    Repeater {
        model: page.parts
        Item {
            required property var modelData
            required property int index
            x: Look.pad + Look.barInsetLeft + (index % page.perRow) * Look.legendColumn
            y: Look.legendY + Math.floor(index / page.perRow) * Look.legendRow
            width: Look.legendColumn - 12
            height: 36
            Rectangle {
                width: 10
                height: 10
                radius: 2.5
                color: Look.partFill(modelData.color)
                border.width: 1
                border.color: Look.partLine(modelData.color)
            }
            Label {
                x: 16.5
                y: 5 - height / 2
                width: parent.width - x
                elide: Text.ElideRight
                text: modelData.name
                font.pixelSize: 12
                font.weight: 700
                color: Look.text
            }
            Label {
                x: 16.5
                y: 26 - height / 2
                width: parent.width - x
                elide: Text.ElideRight
                text: modelData.text
                font.pixelSize: 12
                color: Look.faint
            }
        }
    }

    // The table.
    Rectangle {
        id: table
        x: Look.pad
        y: page.tableY
        width: page.inner
        height: page.rows * Look.tableRow + 1
        radius: 4
        color: Look.tableFill
        border.width: 1
        border.color: Look.tableRim
        readonly property real half: Math.round(width / 2)

        Rectangle {
            x: table.half - 0.5
            y: 10
            width: 1
            height: parent.height - 20
            color: Look.tableRim
        }
        Repeater {
            model: [page.told?.left ?? [], page.told?.right ?? []]
            Item {
                id: column
                required property var modelData
                required property int index
                x: index === 0 ? 0 : table.half
                width: index === 0 ? table.half : table.width - table.half
                height: table.height
                Repeater {
                    model: column.modelData
                    Item {
                        id: row
                        required property var modelData
                        required property int index
                        y: 1 + index * Look.tableRow
                        width: column.width
                        height: Look.tableRow
                        Label {
                            id: name
                            x: column.index === 0 ? Look.tablePad : Look.tablePad + 3
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData[0]
                            font.pixelSize: 12
                            color: Look.text
                        }
                        Label {
                            x: name.x + name.implicitWidth + 10
                            width: parent.width - x - Look.tablePad + 1
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideMiddle
                            text: row.modelData[1]
                            font.pixelSize: 12
                            color: Look.text
                        }
                        // The rule under it, short of the edges and of the
                        // middle.
                        Rectangle {
                            visible: row.index < column.modelData.length - 1
                            x: 10
                            y: parent.height - 1
                            width: parent.width - 20
                            height: 1
                            color: Look.tableRim
                        }
                    }
                }
            }
        }
    }
}
