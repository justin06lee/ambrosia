import QtQuick
import QtQuick.Shapes
import Ambrosia
import Files

// The window's tabs, as Finder's (File ▸ New Tab, ⌘T), measured from macOS
// 27's window tab bar in Dark (2026-11-28, on windows of a program of our
// own, behind everything): a strip 36 tall under the toolbar, in it one
// capsule 28 tall from 8 in holding every tab at an equal share, the tab
// in front a piece of it 24 tall, 2 in, a shade nearer the window's
// ground; hairlines between tabs that aren't in front; names in 11,
// centered; a disc 28 across at the right end with a plus, for a new tab.
// The pointer over a tab brings a close button to its left end. A tab is
// dragged along the bar to another place; a file held over a tab brings
// that tab forward, and dropped on it goes to its folder.
Item {
    id: bar

    required property var finder
    readonly property var names: finder.tabNames
    readonly property int count: names.length
    readonly property int front: finder.tabAt
    readonly property bool lit: finder.looksActive

    height: Finder.tabStrip
    Accessible.role: Accessible.PageTabList
    Accessible.name: "Tab bar, " + count + (count === 1 ? " tab" : " tabs")

    // The strip's ground, and the piece above it under the toolbar: the
    // view starts lower, and what scrolls under its top must not show here.
    Rectangle {
        y: -16
        width: parent.width
        height: parent.height + 16
        color: Finder.content
    }

    Rectangle {
        id: trough
        x: 8
        width: bar.width - 8 - 8 - 28 - 6
        height: 28
        radius: 14
        color: Finder.tabTrough
        border.width: 0.5
        border.color: Finder.tabRim
        readonly property real share: (width - 4) / Math.max(1, bar.count)

        function tabAt(x) {
            return Math.max(0, Math.min(bar.count - 1, Math.floor((x - 2) / share)));
        }

        Rectangle {
            x: 2 + bar.front * trough.share
            y: 2
            width: trough.share
            height: 24
            radius: 12
            color: Finder.tabFront
        }
        Repeater {
            model: bar.count
            Item {
                id: tab
                required property int index
                readonly property bool front: index === bar.front
                readonly property bool under: area.over === index
                x: 2 + index * trough.share
                y: 2
                width: trough.share
                height: 24
                Accessible.role: Accessible.PageTab
                Accessible.name: bar.names[index] ?? ""
                Accessible.selected: front

                // A hairline before it, unless it or the one before is in
                // front.
                Rectangle {
                    visible: tab.index > 0 && !tab.front && tab.index - 1 !== bar.front
                    x: -0.5
                    y: 4
                    width: 1
                    height: 16
                    color: Finder.tabRule
                }
                Label {
                    x: 26
                    width: parent.width - 52
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: bar.names[tab.index] ?? ""
                    font.pixelSize: 11
                    color: !bar.lit ? Theme.color.label.tertiary : tab.front ? Theme.color.label.primary : Theme.color.label.secondary
                }
                // Close, while the pointer is over the tab.
                Item {
                    visible: tab.under && !area.dragged
                    x: 4
                    y: 3
                    width: 18
                    height: 18
                    Rectangle {
                        anchors.fill: parent
                        radius: 9
                        visible: area.overClose
                        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.1)
                    }
                    Shape {
                        anchors.centerIn: parent
                        width: 8
                        height: 8
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: Theme.color.label.secondary
                            strokeWidth: 1.4
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            PathSvg { path: "M0.800 0.800L7.200 7.200M7.200 0.800L0.800 7.200" }
                        }
                    }
                }
            }
        }

        // One pair of hands for every tab: the tabs are drawn anew when
        // their number changes, and a press that began on one must live
        // through that.
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            // A drag along the bar is the tab's, not the window's (which
            // moves by a drag anywhere on its top otherwise).
            preventStealing: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            property int over: -1
            property bool overClose: false
            property int held: -1
            property real from: 0
            property bool dragged: false
            property bool closing: false

            function look(x, y) {
                over = containsMouse ? trough.tabAt(x) : -1;
                const within = x - 2 - over * trough.share;
                overClose = over >= 0 && within >= 4 && within <= 22 && y >= 5 && y <= 23;
            }
            onEntered: look(mouseX, mouseY)
            onExited: {
                over = -1;
                overClose = false;
            }
            onPressed: (mouse) => {
                look(mouse.x, mouse.y);
                if (mouse.button === Qt.RightButton) {
                    const at = mapToItem(null, mouse.x, mouse.y);
                    bar.finder.tabMenu(over, at.x, at.y);
                    return;
                }
                if (mouse.button === Qt.MiddleButton) {
                    bar.finder.closeTab(over);
                    return;
                }
                held = over;
                from = mouse.x;
                dragged = false;
                closing = overClose;
                if (!closing)
                    bar.finder.showTab(held);
            }
            onPositionChanged: (mouse) => {
                if (held < 0 || closing || !(mouse.buttons & Qt.LeftButton)) {
                    look(mouse.x, mouse.y);
                    return;
                }
                if (Math.abs(mouse.x - from) > 8)
                    dragged = true;
                if (!dragged)
                    return;
                const to = trough.tabAt(mouse.x);
                if (to !== held) {
                    bar.finder.moveTab(held, to);
                    held = to;
                }
            }
            onReleased: (mouse) => {
                if (mouse.button !== Qt.LeftButton)
                    return;
                look(mouse.x, mouse.y);
                if (closing && overClose && over === held)
                    bar.finder.closeTab(held);
                held = -1;
                dragged = false;
                closing = false;
            }
        }

        // A drag of files: held over a tab it comes forward; dropped, they
        // go to its folder.
        DropArea {
            id: drops
            anchors.fill: parent
            keys: ["text/uri-list"]
            property int over: -1
            onEntered: (drag) => {
                drag.accept(Qt.MoveAction);
                bar.finder.springOver("");
                over = trough.tabAt(drag.x);
                forward.restart();
            }
            onPositionChanged: (drag) => {
                const at = trough.tabAt(drag.x);
                if (at !== over) {
                    over = at;
                    forward.restart();
                }
            }
            onExited: {
                forward.stop();
                over = -1;
                bar.finder.springLeft();
            }
            onDropped: (drop) => {
                forward.stop();
                const to = over;
                over = -1;
                drop.accept(to >= 0 ? bar.finder.dropOn(drop.urls, bar.finder.tabUrl(to)) : Qt.IgnoreAction);
            }
        }
        Timer {
            id: forward
            interval: 700
            onTriggered: if (drops.over >= 0) bar.finder.showTab(drops.over)
        }
    }

    Rectangle {
        x: bar.width - 8 - 28
        width: 28
        height: 28
        radius: 14
        color: Finder.tabTrough
        border.width: 0.5
        border.color: Finder.tabRim
        Accessible.role: Accessible.Button
        Accessible.name: "New Tab"
        Rectangle {
            anchors.fill: parent
            radius: 14
            visible: plus.pressed
            color: Theme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)
        }
        Shape {
            anchors.centerIn: parent
            width: 10
            height: 10
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: bar.lit ? Theme.color.label.secondary : Theme.color.label.tertiary
                strokeWidth: 1.4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M5 0.500V9.500M0.500 5H9.500" }
            }
        }
        MouseArea {
            id: plus
            anchors.fill: parent
            onClicked: bar.finder.newTab()
        }
    }
}
