import QtQuick
import Ambrosia
import ActivityMonitor
import "monitor.mjs" as Monitor

// Under the table: a rule, and a box in three panes that says how the
// whole computer stands on the tab in view, as a Mac's does: the
// processor's shares and load, memory and its pressure, the energy all
// processes take, the disks' traffic and the network's. The disks' and the
// network's graphs draw either counts or bytes (a click on the graph's
// name chooses), and the numbers the graph draws take its colors.
Item {
    id: panel

    required property Window window
    readonly property var stats: window.stats
    readonly property string tabKey: window.tabKey
    // Where the box's two inner rules stand, measured on each tab.
    readonly property var cuts: ({ cpu: [197.5, 381.5], memory: [193.5, 385.5], energy: [197.5, 381.5], disk: [190.5, 388.5], network: [195.5, 393.5] })[tabKey] ?? [197.5, 381.5]

    height: Look.panel + 1

    Rectangle {
        width: parent.width
        height: 1
        color: Look.boxRule
    }

    component Pane: Item {
        property int place: 0
        x: place === 0 ? 0 : panel.cuts[place - 1] + 1
        width: (place === 2 ? box.width : panel.cuts[place]) - x
        height: box.height
    }
    // A graph under its name; a name with a choice opens it on a click.
    component GraphPane: Pane {
        id: pane
        property string title
        property var choices: []
        property string choice
        property alias history: drawing.history
        property alias kind: drawing.kind
        property alias most: drawing.most
        property alias up: drawing.up
        property alias down: drawing.down
        signal chosen(string value)

        Row {
            id: heading
            anchors.horizontalCenter: parent.horizontalCenter
            y: 11.75 - height / 2
            spacing: 10
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pane.title
                font.family: Theme.uiFont
                font.pixelSize: 10
                font.weight: 700
                font.letterSpacing: 0.4
                color: Look.graphTitle
                renderType: Text.NativeRendering
            }
            Glyph {
                visible: pane.choices.length > 0
                anchors.verticalCenter: parent.verticalCenter
                name: "chevronUpDown"
                size: 10
                weight: 2.6
                color: Look.graphTitle
            }
        }
        MouseArea {
            anchors.fill: heading
            anchors.margins: -5
            enabled: pane.choices.length > 0
            onPressed: chooser.openUnder(heading)
        }
        PopupMenu {
            id: chooser
            items: pane.choices
            current: pane.choice
            onChosen: (value) => pane.chosen(value)
            onClosed: panel.window.takeKeys()
        }
        Rectangle {
            x: 10
            y: 23
            width: parent.width - 20
            height: 1
            color: Look.boxRule
        }
        Graph {
            id: drawing
            x: 3
            y: 26
            width: parent.width - 6
            height: parent.height - y - 3
        }
    }

    Rectangle {
        id: box
        x: Math.round((parent.width - width) / 2)
        y: 1 + Look.boxTop
        width: panel.tabKey === "network" ? Look.boxWidth + 10 : Look.boxWidth
        height: Look.box
        radius: 5
        color: Look.boxFill
        border.width: 1
        border.color: Look.boxRule

        Repeater {
            model: panel.cuts
            Rectangle {
                required property real modelData
                x: modelData
                width: 1
                height: box.height
                color: Look.boxRule
            }
        }

        // CPU.
        Pane {
            visible: panel.tabKey === "cpu"
            place: 0
            StatRows {
                anchors.fill: parent
                ruled: 2
                rows: [
                    { label: "System:", value: Monitor.percent(panel.stats.cpu.system, 2) + "%", color: Look.red },
                    { label: "User:", value: Monitor.percent(panel.stats.cpu.user, 2) + "%", color: Look.blue },
                    { label: "Idle:", value: Monitor.percent(panel.stats.cpu.idle, 2) + "%" },
                ]
            }
        }
        GraphPane {
            visible: panel.tabKey === "cpu"
            place: 1
            title: "CPU LOAD"
            kind: "stack"
            most: 100
            history: panel.stats.cpuHistory
        }
        Pane {
            visible: panel.tabKey === "cpu"
            place: 2
            StatRows {
                anchors.fill: parent
                ruled: 2
                rows: [
                    { label: "Threads:", value: Monitor.count(panel.stats.threads) },
                    { label: "Processes:", value: Monitor.count(panel.stats.count) },
                ]
            }
        }

        // Memory.
        GraphPane {
            visible: panel.tabKey === "memory"
            place: 0
            title: "MEMORY PRESSURE"
            kind: "area"
            most: 1
            up: panel.stats.memory.level === "critical" ? Look.red : panel.stats.memory.level === "warning" ? Look.yellow : Look.green
            history: panel.stats.memoryHistory
        }
        Pane {
            visible: panel.tabKey === "memory"
            place: 1
            StatRows {
                anchors.fill: parent
                ruled: 3
                rows: [
                    { label: "Physical Memory:", value: Monitor.bytes(panel.stats.memory.physical) },
                    { label: "Memory Used:", value: Monitor.bytes(panel.stats.memory.used) },
                    { label: "Cached Files:", value: Monitor.bytes(panel.stats.memory.cached) },
                    { label: "Swap Used:", value: Monitor.bytes(panel.stats.memory.swapUsed) },
                ]
            }
        }
        Pane {
            visible: panel.tabKey === "memory"
            place: 2
            StatRows {
                anchors.fill: parent
                first: 27.25
                pitch: 17.75
                leftPad: 13
                rightPad: 13
                rows: [
                    { label: "App Memory:", value: Monitor.bytes(panel.stats.memory.app) },
                    { label: "Wired Memory:", value: Monitor.bytes(panel.stats.memory.wired) },
                    { label: "Compressed:", value: Monitor.bytes(panel.stats.memory.compressed) },
                ]
            }
        }
        // The three are what Memory Used is made of: the rule between the
        // panes points at that row.
        Item {
            visible: panel.tabKey === "memory"
            x: panel.cuts[1] - 5
            y: 34.75 - 7
            width: 6
            height: 14
            clip: true
            Rectangle {
                x: 2
                y: 2.5
                width: 9
                height: 9
                rotation: 45
                color: Look.boxFill
                border.width: 1
                border.color: Look.boxRule
            }
        }

        // Energy.
        GraphPane {
            visible: panel.tabKey === "energy"
            place: 0
            title: "ENERGY IMPACT"
            kind: "area"
            most: Monitor.ceiling(panel.stats.energyHistory, 20)
            history: panel.stats.energyHistory
        }

        // Disk.
        Pane {
            visible: panel.tabKey === "disk"
            place: 0
            StatRows {
                anchors.fill: parent
                ruled: 3
                readonly property bool drawn: panel.window.diskGraph === "io"
                rows: [
                    { label: "Reads in:", value: Monitor.count(panel.stats.now.reads) },
                    { label: "Writes out:", value: Monitor.count(panel.stats.now.writes) },
                    { label: "Reads in/sec:", value: Monitor.count(panel.stats.rates.reads), color: drawn ? Look.blue : Look.statText },
                    { label: "Writes out/sec:", value: Monitor.count(panel.stats.rates.writes), color: drawn ? Look.red : Look.statText },
                ]
            }
        }
        GraphPane {
            visible: panel.tabKey === "disk"
            place: 1
            title: panel.window.diskGraph === "io" ? "IO" : "DATA"
            choices: [{ text: "IO", value: "io" }, { text: "Data", value: "data" }]
            choice: panel.window.diskGraph
            onChosen: (value) => panel.window.diskGraph = value
            kind: "mirror"
            history: panel.window.diskGraph === "io" ? panel.stats.ioHistory : panel.stats.diskDataHistory
            most: Monitor.ceiling(history, panel.window.diskGraph === "io" ? 50 : 1024 * 1024)
        }
        Pane {
            visible: panel.tabKey === "disk"
            place: 2
            StatRows {
                anchors.fill: parent
                ruled: 3
                leftPad: 13
                rightPad: 13
                readonly property bool drawn: panel.window.diskGraph === "data"
                rows: [
                    { label: "Data read:", value: Monitor.bytes(panel.stats.now.readBytes) },
                    { label: "Data written:", value: Monitor.bytes(panel.stats.now.writtenBytes) },
                    { label: "Data read/sec:", value: Monitor.bytes(panel.stats.rates.readBytes), color: drawn ? Look.blue : Look.statText },
                    { label: "Data written/sec:", value: Monitor.bytes(panel.stats.rates.writtenBytes), color: drawn ? Look.red : Look.statText },
                ]
            }
        }

        // Network.
        Pane {
            visible: panel.tabKey === "network"
            place: 0
            StatRows {
                anchors.fill: parent
                ruled: 3
                readonly property bool drawn: panel.window.networkGraph === "packets"
                rows: [
                    { label: "Packets in:", value: Monitor.count(panel.stats.now.packetsIn) },
                    { label: "Packets out:", value: Monitor.count(panel.stats.now.packetsOut) },
                    { label: "Packets in/sec:", value: Monitor.count(panel.stats.rates.packetsIn), color: drawn ? Look.blue : Look.statText },
                    { label: "Packets out/sec:", value: Monitor.count(panel.stats.rates.packetsOut), color: drawn ? Look.red : Look.statText },
                ]
            }
        }
        GraphPane {
            visible: panel.tabKey === "network"
            place: 1
            title: panel.window.networkGraph === "packets" ? "PACKETS" : "DATA"
            choices: [{ text: "Packets", value: "packets" }, { text: "Data", value: "data" }]
            choice: panel.window.networkGraph
            onChosen: (value) => panel.window.networkGraph = value
            kind: "mirror"
            history: panel.window.networkGraph === "packets" ? panel.stats.packetsHistory : panel.stats.networkDataHistory
            most: Monitor.ceiling(history, panel.window.networkGraph === "packets" ? 20 : 20 * 1024)
        }
        Pane {
            visible: panel.tabKey === "network"
            place: 2
            StatRows {
                anchors.fill: parent
                ruled: 3
                leftPad: 13
                rightPad: 13
                readonly property bool drawn: panel.window.networkGraph === "data"
                rows: [
                    { label: "Data received:", value: Monitor.bytes(panel.stats.now.bytesIn) },
                    { label: "Data sent:", value: Monitor.bytes(panel.stats.now.bytesOut) },
                    { label: "Download:", value: Monitor.bitRate(panel.stats.rates.bytesIn), color: drawn ? Look.blue : Look.statText },
                    { label: "Upload:", value: Monitor.bitRate(panel.stats.rates.bytesOut), color: drawn ? Look.red : Look.statText },
                ]
            }
        }
    }
}
