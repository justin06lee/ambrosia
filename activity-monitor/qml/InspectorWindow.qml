import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Window
import Qt.labs.platform as Platform
import Ambrosia
import ActivityMonitor
import "monitor.mjs" as Monitor

// A process's inspector, measured from macOS 27's: who it is (the file it
// runs, its parent, its group, its user, how much of a processor it has)
// over three tabs in a box: its memory, its counts, and its open files.
// Read again at each of the Sampler's readings; a process that has ended
// keeps its last numbers. Left out, not drawn dead: Sample, and what only
// a Mac's kernel counts (ports, Mach messages, system calls, hangs).
Window {
    id: win

    required property int pid
    // The main window: its readings say this process's name and share.
    required property var monitor
    property var about: ({})
    property string files: ""
    property bool gone: false
    property int tabIndex: 0
    readonly property var process: monitor.all.find(p => p.pid === win.pid) ?? null
    property string name: ""
    property real cpu: -1
    onProcessChanged: {
        if (process !== null) {
            name = process.name;
            cpu = process.cpu;
        }
    }

    signal inspectRequested(int pid)

    property int menusOpen: 0
    readonly property bool looksActive: active || menusOpen > 0 || App.active
    readonly property int corner: Look.inspectorRadius

    function refresh() {
        const read = Sampler.inspect(pid);
        if (read.gone) {
            gone = true;
            return;
        }
        about = read;
        if (tabIndex === 2)
            files = Sampler.openFiles(pid);
    }
    onTabIndexChanged: refresh()
    function takeKeys() {
        keys.forceActiveFocus();
    }
    function toggleZoom() {}
    function quit() {
        if (!gone && pid > 1)
            alert.quit({ pid: pid, name: name, user: process?.user ?? "", uid: process?.uid ?? -1 });
    }

    // Taller with the open files, as a Mac's is. Set by hand, not bound: a
    // size the compositor hands the window would undo a binding.
    readonly property int wanted: tabIndex === 2 ? Look.inspectorHeight + 44 : Look.inspectorHeight
    onWantedChanged: {
        minimumHeight = Math.min(minimumHeight, wanted);
        maximumHeight = Math.max(maximumHeight, wanted);
        height = wanted;
        minimumHeight = wanted;
        maximumHeight = wanted;
    }
    width: Look.inspectorWidth
    height: Look.inspectorHeight
    minimumWidth: Look.inspectorWidth
    maximumWidth: Look.inspectorWidth
    minimumHeight: Look.inspectorHeight
    maximumHeight: Look.inspectorHeight
    visible: false
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: name + " (" + pid + ")"

    readonly property Appearance appearance: Appearance {}
    Platform.MenuBar {
        Platform.Menu {
            title: "File"
            Platform.MenuItem { text: "Close"; shortcut: "Ctrl+W"; onTriggered: win.close() }
        }
        Platform.Menu {
            title: "Window"
            Platform.MenuItem { text: "Minimize"; shortcut: "Ctrl+M"; onTriggered: win.showMinimized() }
        }
    }
    Connections {
        target: Sampler
        function onSampled() {
            win.refresh();
        }
    }
    Component.onCompleted: {
        if (process !== null) {
            name = process.name;
            cpu = process.cpu;
        }
        refresh();
        visible = true;
        takeKeys();
    }
    onVisibleChanged: {
        if (visible) {
            App.decorate(win, Look.inspectorRadius);
            Qt.callLater(App.shown, win, true);
        }
    }
    Shortcut { sequences: ["Ctrl+W", "Meta+W"]; onActivated: win.close(); onActivatedAmbiguously: win.close() }
    Shortcut { sequences: ["Ctrl+M", "Meta+M"]; onActivated: win.showMinimized(); onActivatedAmbiguously: win.showMinimized() }

    component Words: Text {
        font.family: Theme.uiFont
        font.pixelSize: 13
        color: Look.statText
        renderType: Text.NativeRendering
    }
    // Where what the names name begins: a Mac's place, or past the longest
    // name where our letters run wider than its.
    FontMetrics {
        id: letters
        font.family: Theme.uiFont
        font.pixelSize: 13
    }
    function past(names, least) {
        return Math.max(least, ...names.map(name => Math.ceil(letters.advanceWidth(name)) + 8));
    }
    readonly property real whoAt: past(["Executable Path:", "Parent Process:", "Process Group:"], 88.5)
    readonly property real memoryAt: past(["Virtual Memory Size:", "Private Memory Size:"], 118)
    readonly property real countsAt: past(["Context Switches:"], 101)

    // A name and, at `at`, what it names; 22 a line.
    component Fact: Item {
        property string label
        property string value
        property real at: 88.5
        height: 22
        Words { anchors.verticalCenter: parent.verticalCenter; text: parent.label }
        Words {
            x: parent.at
            width: parent.width - x
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: parent.value
            font.features: { "tnum": 1 }
        }
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: win.corner
        color: Look.inspectorGround

        Item {
            id: keys
            focus: true
            Keys.onEscapePressed: win.close()
        }

        // The title bar: the lights and the process's name and id.
        Rectangle {
            width: parent.width
            height: Look.titleBar
            topLeftRadius: win.corner
            topRightRadius: win.corner
            color: Look.inspectorBar
            DragHandler {
                target: null
                onActiveChanged: if (active) win.startSystemMove()
            }
            TapHandler { onTapped: win.takeKeys() }
        }
        Rectangle {
            y: Look.titleBar
            width: parent.width
            height: 1
            color: Look.dark ? "#313130" : "#dadada"
        }
        TrafficLights {
            x: 13
            y: (Look.titleBar - Look.lightSize) / 2
            window: win
            zoomable: false
        }
        Label {
            x: 85
            width: parent.width - x - 16
            height: Look.titleBar
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: win.title
            style: Theme.text.headline
            font.weight: 700
            color: win.looksActive ? Look.title : Look.titleInactive
        }

        // Who it is.
        Fact {
            x: 20.5
            y: 48
            width: 492
            at: win.whoAt
            label: "Executable Path:"
            value: win.about.exe ?? ""
        }
        // Show the file in Files.
        Item {
            visible: (win.about.exe ?? "") !== ""
            x: 525
            y: 52
            width: 14
            height: 14
            Glyph { anchors.centerIn: parent; name: "disc"; size: 15; color: Look.subtitle }
            Glyph { anchors.centerIn: parent; name: "arrowRight"; size: 10; color: Look.inspectorGround }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -3
                onClicked: App.reveal(win.about.exe)
            }
        }
        Words { x: 20.5; y: 70; height: 22; verticalAlignment: Text.AlignVCenter; text: "Parent Process:" }
        Words {
            id: parentLink
            x: 20.5 + win.whoAt
            y: 70
            height: 22
            verticalAlignment: Text.AlignVCenter
            text: win.about.parent ?? ""
            color: Look.link
            font.underline: true
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: (win.about.parentPid ?? 0) > 0
                onClicked: win.inspectRequested(win.about.parentPid)
            }
        }
        Row {
            x: Math.max(284, parentLink.x + parentLink.width + 24)
            y: 70
            height: 22
            spacing: 6
            Words { anchors.verticalCenter: parent.verticalCenter; text: "User:" }
            Words { anchors.verticalCenter: parent.verticalCenter; text: win.about.user ?? "" }
        }
        Fact {
            x: 20.5
            y: 92
            width: 500
            at: win.whoAt
            label: "Process Group:"
            value: win.about.group ?? ""
        }
        Fact {
            x: 20.5
            y: 114
            width: 250
            at: win.whoAt
            label: "% CPU:"
            value: win.gone ? "" : Monitor.percent(win.cpu, 2)
        }

        // The box, its three tabs astride its top edge.
        Rectangle {
            id: box
            x: 20
            y: 150
            width: parent.width - 40
            height: parent.height - y - 48
            radius: 8
            color: Look.inspectorBox
            border.width: 1
            border.color: Look.inspectorBoxRim

            Column {
                visible: win.tabIndex === 0
                x: 23
                y: 33
                Repeater {
                    model: [
                        { label: "Real Memory Size:", value: Monitor.bytes(win.about.rss) },
                        { label: "Virtual Memory Size:", value: Monitor.bytes(win.about.vsize) },
                        { label: "Shared Memory Size:", value: Monitor.bytes(win.about.shared) },
                        { label: "Private Memory Size:", value: Monitor.bytes(win.about.own) },
                    ]
                    Fact {
                        required property var modelData
                        width: 420
                        at: win.memoryAt
                        label: modelData.label
                        value: modelData.value
                    }
                }
            }
            Column {
                visible: win.tabIndex === 1
                x: 23
                y: 33
                Repeater {
                    model: [
                        { label: "Threads:", value: Monitor.count(win.about.threads) },
                        { label: "CPU Time:", value: Monitor.cpuTime(win.about.cpuTime) },
                        { label: "Context Switches:", value: Monitor.count(win.about.switches) },
                        { label: "Faults:", value: Monitor.count(win.about.faults) },
                    ]
                    Fact {
                        required property var modelData
                        width: 250
                        at: win.countsAt
                        label: modelData.label
                        value: modelData.value
                    }
                }
            }
            Fact {
                visible: win.tabIndex === 1
                x: 279
                y: 33
                width: 220
                at: win.past(["Page Ins:"], 80)
                label: "Page Ins:"
                value: Monitor.count(win.about.pageIns)
            }
            // Its open files: a descriptor, then what it is, as a Mac lists
            // them. Empty for a process the kernel won't show us.
            Rectangle {
                visible: win.tabIndex === 2
                x: 12
                y: 22
                width: parent.width - 24
                height: parent.height - 34
                color: Look.well
                border.width: 1
                border.color: Look.inspectorBoxRim
                Flickable {
                    id: listing
                    anchors.fill: parent
                    anchors.margins: 1
                    contentWidth: width
                    contentHeight: lines.implicitHeight + 8
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    acceptedButtons: Qt.NoButton // the mouse selects text
                    Controls.ScrollBar.vertical: ScrollThumb {}
                    TextEdit {
                        id: lines
                        x: 5
                        y: 4
                        width: listing.width - 10
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.WrapAnywhere
                        text: win.files
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                        color: Look.statText
                        selectionColor: Theme.accent.highlight
                        selectedTextColor: Look.statText
                        renderType: Text.NativeRendering
                    }
                }
            }
        }
        Rectangle {
            id: segments
            readonly property var names: ["Memory", "Statistics", "Open Files and Ports"]
            anchors.horizontalCenter: box.horizontalCenter
            y: box.y - 12
            width: tabsRow.width
            height: 24
            radius: 8
            color: Look.segments

            Row {
                id: tabsRow
                Repeater {
                    model: segments.names
                    Item {
                        id: segment
                        required property string modelData
                        required property int index
                        width: word.implicitWidth + 28
                        height: 24
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2.5
                            radius: 6
                            visible: win.tabIndex === segment.index
                            color: Look.segmentChosen
                        }
                        Words {
                            id: word
                            anchors.centerIn: parent
                            text: segment.modelData
                        }
                        MouseArea {
                            anchors.fill: parent
                            onPressed: win.tabIndex = segment.index
                        }
                    }
                }
            }
        }

        PushButton {
            x: 23
            y: parent.height - 40
            height: 20
            radius: 6
            visible: win.pid > 1
            enabled: !win.gone
            text: "Quit"
            onClicked: win.quit()
        }

        Alert {
            id: alert
            anchors.fill: parent
            window: win
        }

        Rectangle {
            anchors.fill: parent
            radius: win.corner
            color: "transparent"
            border.width: 0.5
            border.color: Look.rim
        }
    }
}
