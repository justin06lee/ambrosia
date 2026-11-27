import QtQuick
import QtQuick.Controls.Basic as Controls
import Ambrosia
import ActivityMonitor
import "monitor.mjs" as Monitor

// The processes: a heading 28 tall over rows 24 tall, every other one a
// shade lighter all the way down the view. The name column takes what the
// tab's others leave; a click on a heading sorts by it (again, the other
// way), a drag on the rule after one makes its column wider or narrower.
// The rows aren't a list view: a screenful of them is drawn and each shows
// whichever process has come to stand at its place, so a new reading
// changes what is written without anything moving or the view jumping.
Item {
    id: table

    required property Window window
    readonly property var tab: window.tab
    readonly property var rows: window.rows
    readonly property var columns: tab.columns
    // The width the user dragged a column to: "tab/column" to points.
    property var widths: ({})

    function columnWidth(i) {
        // As the tab changes, a cell of the tab before may still ask.
        const column = columns[i];
        return column ? widths[tab.key + "/" + column.key] ?? column.width : 0;
    }
    readonly property real fixed: {
        let sum = Look.trailing;
        for (let i = 0; i < columns.length; ++i)
            sum += columnWidth(i);
        return sum;
    }
    // Where the window is too narrow for the name and the columns, the
    // table is wider than its view and moves sideways under it.
    readonly property real wide: Math.max(width, Look.minName + fixed)
    readonly property real nameWidth: wide - fixed
    function columnX(i) {
        let x = nameWidth;
        for (let k = 0; k < i; ++k)
            x += columnWidth(k);
        return x;
    }
    // Bring row `index` into view.
    function reveal(index) {
        const top = Look.rowsTop + index * Look.row;
        if (top < flick.contentY)
            flick.contentY = Math.max(0, top - Look.rowsTop);
        else if (top + Look.row > flick.contentY + flick.height)
            flick.contentY = top + Look.row - flick.height;
    }
    readonly property int pageRows: Math.max(1, Math.floor(flick.height / Look.row) - 1)

    // A heading: its words, bold with an arrow when the rows go by it.
    component Heading: Item {
        id: heading
        property string key
        property string title
        property string side: "right"
        // Where words set from the left begin.
        property real lead: Look.headPad
        readonly property bool sorting: table.window.sort.key === key
        height: Look.header

        Text {
            id: words
            anchors.verticalCenter: parent.verticalCenter
            x: heading.side === "left" ? heading.lead
                : heading.side === "center" ? (heading.width - width) / 2
                : heading.width - width - (heading.sorting ? 21 : Look.headPad)
            width: Math.min(implicitWidth, heading.width - (heading.side === "left" ? heading.lead + (heading.sorting ? 21 : 6) : 6 + (heading.sorting ? 21 : Look.headPad)))
            elide: Text.ElideRight
            text: heading.title
            font.family: Theme.uiFont
            font.pixelSize: Look.textSize
            font.weight: heading.sorting ? 700 : 500
            color: Look.headText
            renderType: Text.NativeRendering
        }
        Glyph {
            visible: heading.sorting
            x: heading.width - 8 - 7.5
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 0.5
            name: "chevronDown"
            size: 8
            weight: 2.6
            color: Look.sortArrow
            rotation: table.window.sort.descending ? 0 : 180
        }
        MouseArea {
            anchors.fill: parent
            onClicked: table.window.sortBy(heading.key)
        }
    }

    Item {
        width: parent.width
        height: Look.header
        clip: true

        Item {
            id: head
            x: -flick.contentX
            width: table.wide
            height: Look.header

            Heading {
                width: table.nameWidth
                key: "name"
                title: table.tab.name
                side: "left"
                // The name's heading begins where the icons do.
                lead: Look.iconX + 0.5
            }
            Repeater {
                model: table.columns
                Heading {
                    required property var modelData
                    required property int index
                    x: table.columnX(index)
                    width: table.columnWidth(index)
                    key: modelData.key
                    title: modelData.title
                    side: Monitor.alignment(modelData)
                }
            }
            // The rule after each column, and the hand that drags it.
            Repeater {
                model: table.columns.length + 1
                Item {
                    id: rule
                    required property int index
                    // After the name column, then after each of the others.
                    readonly property int column: index - 1
                    x: (column < 0 ? table.nameWidth : table.columnX(column) + table.columnWidth(column)) - 1
                    width: 1
                    height: Look.header
                    Rectangle {
                        y: 6
                        width: 1
                        height: 16
                        color: Look.columnRule
                    }
                    MouseArea {
                        x: -4
                        width: 9
                        height: parent.height
                        enabled: rule.column >= 0
                        cursorShape: rule.column >= 0 ? Qt.SplitHCursor : Qt.ArrowCursor
                        preventStealing: true
                        property real from: 0
                        property real was: 0
                        onPressed: (mouse) => {
                            from = mapToItem(table, mouse.x, 0).x;
                            was = table.columnWidth(rule.column);
                        }
                        onPositionChanged: (mouse) => {
                            if (!pressed)
                                return;
                            const widths = Object.assign({}, table.widths);
                            widths[table.tab.key + "/" + table.columns[rule.column].key] = Math.max(44, Math.min(400, was + mapToItem(table, mouse.x, 0).x - from));
                            table.widths = widths;
                        }
                    }
                }
            }
        }
    }

    Flickable {
        id: flick
        y: Look.header
        width: parent.width
        height: parent.height - Look.header
        contentWidth: table.wide
        contentHeight: Math.max(height, Look.rowsTop + table.rows.length * Look.row + 4)
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        acceptedButtons: Qt.NoButton // the mouse chooses rows; the wheel moves the table
        Controls.ScrollBar.vertical: ScrollThumb {}
        Controls.ScrollBar.horizontal: ScrollThumb {}

        // Clicks on the rows; the wheel is the flickable's.
        MouseArea {
            width: flick.contentWidth
            height: flick.contentHeight
            function rowAt(y) {
                return Math.floor((y - Look.rowsTop) / Look.row);
            }
            onPressed: (mouse) => {
                table.window.takeKeys();
                const row = table.rows[rowAt(mouse.y)];
                table.window.selected = row ? row.pid : -1;
            }
            onDoubleClicked: (mouse) => {
                const row = table.rows[rowAt(mouse.y)];
                if (row)
                    table.window.inspectRequested(row.pid);
            }
        }

        Repeater {
            model: Math.max(0, Math.ceil(flick.height / Look.row) + 2)
            Item {
                id: slot
                required property int index
                // Which row stands here just now.
                readonly property int at: Math.max(0, Math.floor((flick.contentY - Look.rowsTop) / Look.row)) + index
                readonly property var process: table.rows[at] ?? null
                readonly property bool chosen: process !== null && process.pid === table.window.selected
                readonly property color ink: chosen && table.window.looksActive ? Theme.accent.fg : Look.text
                y: Look.rowsTop + at * Look.row
                width: flick.contentWidth
                height: Look.row

                Rectangle {
                    anchors.fill: parent
                    visible: slot.chosen || slot.at % 2 === 1
                    color: slot.chosen ? Look.chosen(table.window.looksActive) : Look.band
                }
                Image {
                    visible: slot.process !== null && slot.process.icon !== ""
                    x: Look.iconX
                    anchors.verticalCenter: parent.verticalCenter
                    width: Look.icon
                    height: Look.icon
                    sourceSize: Qt.size(2 * Look.icon, 2 * Look.icon)
                    source: slot.process !== null && slot.process.icon !== "" ? "image://icon/" + slot.process.icon : ""
                    asynchronous: false
                }
                Text {
                    x: Look.nameX
                    width: table.nameWidth - x - 8
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: slot.process?.name ?? ""
                    font.family: Theme.uiFont
                    font.pixelSize: Look.textSize
                    color: slot.ink
                    renderType: Text.NativeRendering
                }
                Repeater {
                    model: table.columns
                    Text {
                        required property var modelData
                        required property int index
                        readonly property string side: Monitor.alignment(modelData)
                        x: table.columnX(index) + (side === "left" ? Look.cellPad - 1 : 4)
                        width: table.columnWidth(index) - (side === "left" ? Look.cellPad + 3 : 4 + Look.cellPad)
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: side === "left" ? Text.AlignLeft : side === "center" ? Text.AlignHCenter : Text.AlignRight
                        elide: Text.ElideRight
                        text: slot.process !== null ? Monitor.cell(slot.process, modelData) : ""
                        font.family: Theme.uiFont
                        font.pixelSize: Look.textSize
                        font.features: { "tnum": 1 }
                        color: slot.ink
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
    }
}
