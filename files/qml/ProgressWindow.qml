import QtQuick
import QtQuick.Window
import Ambrosia
import Files

// Finder's progress window: a row for each copy or move that has run for
// over a second (FileOps.jobs), with what it is doing, a bar, how much is
// done and about how long is left, and a button that stops it. It comes
// when the first row does and closes with the last.
Window {
    id: win

    // The window the copy was started in, if one had the keyboard: this
    // one stays in front of it and gives it the keyboard back.
    property Window owner: null
    property bool handedBack: false
    transientParent: owner
    readonly property bool looksActive: active
    readonly property Appearance appearance: Appearance {}

    width: Finder.progressWidth
    height: Finder.progressTitleBar + Math.max(1, FileOps.jobs.count) * Finder.progressRow
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: FileOps.jobs.title

    onActiveChanged: {
        if (active && owner && !handedBack) {
            handedBack = true;
            owner.requestActivate();
        }
    }
    Connections {
        target: FileOps.jobs
        function onCountChanged() {
            if (FileOps.jobs.count === 0)
                win.close();
        }
    }
    // It stays while anything runs: a row's button stops that one.
    onClosing: (close) => close.accepted = FileOps.jobs.count === 0

    onVisibleChanged: if (visible) App.decorate(win, Finder.infoRadius)
    Component.onCompleted: if (visible) App.decorate(win, Finder.infoRadius)

    Rectangle {
        anchors.fill: parent
        radius: Finder.infoRadius
        color: Finder.content
        border.width: 0.5
        border.color: Theme.dark ? "#33ffffff" : "#26000000"

        // The title bar: the lights and the window's name, centered.
        Item {
            width: parent.width
            height: Finder.progressTitleBar
            DragHandler {
                target: null
                onActiveChanged: if (active) win.startSystemMove()
            }
            TrafficLights {
                x: 8
                y: 7
                window: win
            }
            Label {
                anchors.centerIn: parent
                font.pixelSize: 13
                font.weight: 700
                text: win.title
                color: win.active ? Theme.color.label.primary : Theme.color.label.secondary
            }
        }

        Column {
            y: Finder.progressTitleBar
            width: parent.width

            Repeater {
                model: FileOps.jobs
                Item {
                    id: row
                    required property int index
                    required property string title
                    required property string detail
                    required property real fraction
                    width: parent.width
                    height: Finder.progressRow

                    Rectangle {
                        visible: row.index > 0
                        x: Finder.progressMargin
                        width: parent.width - 2 * x
                        height: 1
                        color: Finder.infoRule
                    }
                    Label {
                        x: Finder.progressMargin
                        y: 8
                        width: parent.width - 2 * x
                        font.pixelSize: 13
                        text: row.title
                        elide: Text.ElideMiddle
                    }
                    Rectangle {
                        id: track
                        x: Finder.progressMargin
                        y: 33
                        width: stop.x - 10 - x
                        height: Finder.progressBar
                        radius: height / 2
                        color: Finder.progressTrack
                        clip: true
                        Rectangle {
                            id: fill
                            // How far along; until that is known, a piece that
                            // goes from end to end.
                            readonly property bool sliding: row.fraction < 0
                            width: sliding ? parent.width / 4 : Math.max(height, parent.width * row.fraction)
                            height: parent.height
                            radius: height / 2
                            color: Theme.accent.bg
                            Behavior on width {
                                enabled: row.fraction >= 0
                                NumberAnimation { duration: 250 }
                            }
                            SequentialAnimation on x {
                                running: row.fraction < 0
                                loops: Animation.Infinite
                                NumberAnimation { from: 0; to: track.width * 3 / 4; duration: 900; easing.type: Easing.InOutQuad }
                                NumberAnimation { from: track.width * 3 / 4; to: 0; duration: 900; easing.type: Easing.InOutQuad }
                                onRunningChanged: if (!running) fill.x = 0
                            }
                        }
                    }
                    Rectangle {
                        id: stop
                        x: parent.width - Finder.progressMargin - width
                        y: track.y + track.height / 2 - height / 2
                        width: Finder.progressStop
                        height: width
                        radius: width / 2
                        color: Finder.progressStopFill
                        opacity: overStop.hovered ? 0.75 : 1
                        Glyph {
                            anchors.centerIn: parent
                            name: "close"
                            size: 12
                            color: Finder.content
                        }
                        HoverHandler { id: overStop }
                        TapHandler { onTapped: FileOps.jobs.stop(row.index) }
                    }
                    Label {
                        x: Finder.progressMargin
                        y: 45
                        width: parent.width - 2 * x
                        font.pixelSize: 11
                        text: row.detail
                        elide: Text.ElideRight
                        color: Theme.color.label.secondary
                    }
                }
            }
        }
    }
}
