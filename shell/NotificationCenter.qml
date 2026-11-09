import Quickshell
import QtQuick
import Ambrosia

// Notification Center, which the clock opens as on macOS 26: a column down
// the right of the screen, on the glass of its cards alone. At the top, the
// Focus state (a click switches Do Not Disturb) and Clear All; then the
// notifications by app, the app heard from last first. An app's several
// notifications stack, the newest on top; a click on the stack spreads it,
// with Show Less and a close for the app's whole group above. A click on a
// notification runs it; its close (on hover) clears it. It slides in from
// the edge, as the banners do, and scrolls when it's taller than the screen.
Item {
    id: nc

    property bool open: false
    // Up while open and while sliding out.
    readonly property bool shown: open || slide.running || panel.x < width
    // The cards' glass, for the window's blur: only what's in view.
    readonly property Region blurArea: Region {
        regions: {
            nc.revision;
            const list = [focus.blurArea, inView];
            if (clearAll.visible) list.push(clearAll.blurArea);
            return list;
        }
    }
    Region {
        id: inView
        item: flick
        Region {
            intersection: Intersection.Intersect
            regions: { nc.revision; return nc.cardAreas(); }
        }
    }
    // Which apps' stacks are spread.
    property var spread: ({})
    // Bumped when anything moves, for the blur regions: they follow an
    // item's own geometry only, not its parents' moving or scrolling.
    property int revision: 0
    property real maxHeight: 600

    width: 344
    height: flick.y + flick.height
    visible: shown

    onOpenChanged: if (!open) spread = ({})

    function cardAreas() {
        const list = [];
        for (let i = 0; i < groups.count; i++) {
            const group = groups.itemAt(i);
            if (group) list.push(...group.areas);
        }
        if (empty.visible) list.push(empty.blurArea);
        return list;
    }
    function moved() {
        revision++;
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: nc.open
    }

    // Slides in from past the screen's edge.
    Item {
        id: panel
        width: parent.width
        height: parent.height
        x: nc.open ? 0 : nc.width + Theme.space.s6
        opacity: nc.open ? 1 : 0
        onXChanged: nc.moved()
        Behavior on x {
            NumberAnimation {
                id: slide
                duration: nc.open ? Theme.spring.smooth.duration : Theme.exit.smooth.duration
                easing.type: Easing.OutQuart
            }
        }
        Behavior on opacity { NumberAnimation { duration: nc.open ? Theme.fade.base : Theme.fade.fast } }

        // Focus, and Clear All.
        Item {
            id: topRow
            width: parent.width
            height: 32

            Capsule {
                id: focus
                height: parent.height
                width: focusRow.implicitWidth + Theme.space.s2 + Theme.space.s4
                onClicked: Settings.doNotDisturb = !Settings.doNotDisturb

                Row {
                    id: focusRow
                    x: Theme.space.s1
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.s2

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: Settings.doNotDisturb ? Theme.color.palette.indigo : Theme.color.fill.primary
                        Icon {
                            anchors.centerIn: parent
                            name: "moon"
                            size: 14
                            color: Settings.doNotDisturb ? "white" : Theme.color.label.primary
                        }
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Do Not Disturb"
                        style: Theme.text.headline
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Settings.doNotDisturb ? "On" : "Off"
                        style: Theme.text.callout
                        color: Theme.color.label.secondary
                    }
                }
            }

            Capsule {
                id: clearAll
                visible: NotificationStore.history.length > 0
                anchors.right: parent.right
                height: parent.height
                width: clearLabel.implicitWidth + 2 * Theme.space.s4
                onClicked: NotificationStore.clearAll()

                Label {
                    id: clearLabel
                    anchors.centerIn: parent
                    text: "Clear All"
                    style: Theme.text.callout
                    color: Theme.color.label.primary
                }
            }
        }

        Flickable {
            id: flick
            // Room above and left for the close buttons, which stand out past a
            // card's corner.
            y: topRow.height + Theme.space.s2 - 8
            x: -8
            width: parent.width + 8
            height: Math.min(column.height + 8, Math.max(0, nc.maxHeight - y))
            contentHeight: column.height + 8
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            onContentYChanged: nc.moved()

            Column {
                id: column
                x: 8
                y: 8
                width: nc.width
                spacing: Theme.space.s2
                onHeightChanged: nc.moved()
                onYChanged: nc.moved()

                Repeater {
                    id: groups
                    model: NotificationStore.groups

                    Group {}
                }

                NotificationCard {
                    id: empty
                    readonly property Region blurArea: Region { item: empty; radius: Theme.radius.panel }
                    visible: NotificationStore.history.length === 0
                    width: nc.width
                    blank: true
                    implicitHeight: 64

                    Label {
                        anchors.centerIn: parent
                        text: "No Notifications"
                        style: Theme.text.body
                        color: Theme.color.label.secondary
                    }
                }
            }
        }
    }

    // A glass capsule that takes a click.
    component Capsule: Item {
        id: capsule
        signal clicked
        readonly property Region blurArea: Region { item: capsule; radius: height / 2 }

        Glass {
            anchors.fill: parent
            tint: Theme.color.material.regular.tint
            radius: height / 2
            shadow: Theme.color.shadow.panel
        }
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.color.fill.primary
            opacity: capsuleArea.pressed ? 1 : 0
        }
        MouseArea {
            id: capsuleArea
            anchors.fill: parent
            onClicked: capsule.clicked()
        }
    }

    // One app's notifications: one card, a stack, or spread out.
    component Group: Column {
        id: group
        required property var modelData
        required property int index
        readonly property var records: modelData.records
        readonly property bool stacked: records.length > 1 && !nc.spread[modelData.app]
        readonly property bool isSpread: records.length > 1 && !stacked
        // How many cards show under the top of a stack.
        readonly property int peeks: stacked ? Math.min(records.length - 1, 2) : 0
        readonly property var areas: {
            nc.revision;
            const list = [];
            if (header.visible) list.push(header.blurArea);
            for (let i = 0; i < cards.count; i++) {
                const card = cards.itemAt(i);
                if (card?.visible) list.push(card.blurArea);
            }
            return list;
        }

        width: nc.width
        spacing: Theme.space.s2
        onYChanged: nc.moved()
        onHeightChanged: nc.moved()

        function spreadOut(on) {
            const next = Object.assign({}, nc.spread);
            next[modelData.app] = on;
            nc.spread = next;
        }

        // The app's name, Show Less and a close for all of them, when spread.
        Capsule {
            id: header
            visible: group.isSpread
            width: parent.width
            height: 32
            onClicked: group.spreadOut(false)

            Label {
                x: Theme.space.s4
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - lessLabel.implicitWidth - 2 * Theme.space.s4 - 24
                text: group.modelData.app
                style: Theme.text.headline
                elide: Text.ElideRight
            }
            Label {
                id: lessLabel
                anchors { right: clearApp.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                text: "Show Less"
                style: Theme.text.callout
                color: Theme.color.label.secondary
            }
            Rectangle {
                id: clearApp
                anchors { right: parent.right; rightMargin: Theme.space.s1; verticalCenter: parent.verticalCenter }
                width: 24
                height: 24
                radius: 12
                color: clearAppArea.pressed ? Theme.color.fill.primary : Theme.color.fill.secondary
                Label {
                    anchors.centerIn: parent
                    text: "×"
                    style: Theme.text.body
                    color: Theme.color.label.secondary
                }
                MouseArea {
                    id: clearAppArea
                    anchors.fill: parent
                    onClicked: NotificationStore.clearApp(group.modelData.app)
                }
            }
        }

        // The stack, or each of them when spread. Under a stack's top card,
        // the next ones peek out, narrower.
        Item {
            id: stack
            width: parent.width
            height: (cards.itemAt(0)?.height ?? 64) + group.peeks * Theme.space.s2
            visible: !group.isSpread

            Repeater {
                id: peekCards
                model: group.peeks
                // Only the strip below the card above shows: glass is see-through.
                Item {
                    id: peek
                    required property int index
                    readonly property real cardHeight: cards.itemAt(0)?.height ?? 64
                    z: -index - 1
                    clip: true
                    x: (index + 1) * Theme.space.s3
                    y: cardHeight + index * Theme.space.s2
                    width: stack.width - 2 * x
                    height: Theme.space.s2

                    NotificationCard {
                        y: Theme.space.s2 - peek.cardHeight
                        width: parent.width
                        height: peek.cardHeight
                        blank: true
                        opacity: 1 - 0.2 * (peek.index + 1)
                    }
                }
            }
        }

        Repeater {
            id: cards
            // A stack shows its newest; spread, all of them.
            model: group.isSpread ? group.records : group.records.slice(0, 1)

            NotificationCard {
                id: card
                required property var modelData
                required property int index
                readonly property var notification: NotificationStore.live(modelData.nid)
                readonly property Region blurArea: Region { item: card; radius: Theme.radius.panel }

                // A stack's top card sits over its peeks.
                parent: group.isSpread ? group : stack
                width: nc.width
                appName: modelData.app
                iconSource: modelData.icon
                summary: notification?.summary ?? modelData.summary
                body: notification?.body ?? modelData.body
                time: modelData.time
                now: clock.date
                buttons: notification ? notification.actions.filter(a => a.identifier !== "default") : []
                onActivated: {
                    if (group.stacked) group.spreadOut(true);
                    else NotificationStore.open(modelData);
                }
                onCloseClicked: {
                    if (group.stacked) NotificationStore.clearApp(group.modelData.app);
                    else NotificationStore.dismissOne(modelData);
                }
            }
        }
    }
}
