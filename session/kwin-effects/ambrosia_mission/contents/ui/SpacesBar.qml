import QtQuick
import QtQuick.Effects
import Ambrosia

// Mission Control's strip of the desktops, under the menu bar: their names
// in a row, and once the pointer has been on it, a small picture of each
// with its name under it. A click goes to one; the pointer on a picture
// shows a button that removes it; the + at the right end adds one. Only the
// picture: MissionScreen.qml gives it KWin's desktops and what to draw in
// each, and a sheet draws it where KWin isn't
// (tools/qmlshot/sheets/mission-control.qml).
Item {
    id: bar

    // Rows of { name, current }, in order.
    property var spaces: []
    // Pictures rather than names alone.
    property bool open: false
    // A screen's width over its height: the shape of a picture.
    property real aspect: 16 / 9
    // Draws what is behind the bar (the wallpaper, blurred), filling it.
    property Component backdrop
    // Draws one desktop, filling its parent, whose `entry` is the row.
    property Component shot
    signal picked(int index)
    signal removed(int index)
    signal added()

    // 0 names only, 1 pictures: everything between follows it.
    property real reveal: open ? 1 : 0
    Behavior on reveal {
        NumberAnimation { duration: Theme.spring.snappy.duration; easing.type: Easing.OutCubic }
    }

    readonly property int pad: Theme.size.mission.pad
    readonly property int nameRow: Theme.size.mission.bar - pad
    readonly property int closedHeight: Theme.size.mission.bar
    readonly property int openHeight: pad + Theme.size.mission.space + nameRow + pad / 2
    readonly property int shotHeight: Theme.size.mission.space
    readonly property int shotWidth: Math.round(shotHeight * aspect)

    // The row a point of the bar is on, or -1: where a dragged window lands.
    function indexAt(x, y) {
        if (y < 0 || y > height) return -1;
        for (let i = 0; i < items.count; i++) {
            const item = items.itemAt(i);
            if (!item) continue;
            const left = row.x + item.x;
            if (x >= left && x <= left + item.width) return i;
        }
        return -1;
    }

    implicitHeight: closedHeight + (openHeight - closedHeight) * reveal
    clip: true

    // A click on the bar itself is nobody's: it doesn't leave Mission Control.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
    }

    Loader {
        anchors.fill: parent
        sourceComponent: bar.backdrop
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.color.material.regular.tint
    }

    // The hairline the bar ends on.
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.color.glass.edge
    }

    Row {
        id: row

        anchors.horizontalCenter: parent.horizontalCenter
        height: parent.height
        spacing: Theme.space.s8 + (Theme.space.s5 - Theme.space.s8) * bar.reveal

        Repeater {
            id: items
            model: bar.spaces

            delegate: Item {
                id: space

                required property int index
                required property var modelData
                readonly property bool current: modelData.current === true

                width: name.implicitWidth + (bar.shotWidth - name.implicitWidth) * bar.reveal
                height: bar.height

                // The desktop's picture, with rounded corners.
                Item {
                    id: picture

                    y: bar.pad
                    width: bar.shotWidth
                    height: bar.shotHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: bar.reveal > 0
                    opacity: bar.reveal
                    scale: 0.6 + 0.4 * bar.reveal
                    transformOrigin: Item.Top

                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: corners
                        }

                        Loader {
                            readonly property var entry: space.modelData
                            anchors.fill: parent
                            sourceComponent: bar.shot
                        }
                    }

                    Rectangle {
                        id: corners
                        anchors.fill: parent
                        radius: Theme.radius.row
                        visible: false
                        layer.enabled: true
                    }

                    // The desktop this is: a light line round it.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -2
                        radius: Theme.radius.row + 2
                        color: "transparent"
                        border.width: 2
                        border.color: Qt.rgba(1, 1, 1, space.current ? 0.9 : over.hovered ? 0.45 : 0)
                    }

                    // Removes the desktop; its windows go to the one beside it.
                    Rectangle {
                        x: -width / 3
                        y: -height / 3
                        width: Theme.space.s5
                        height: width
                        radius: width / 2
                        visible: over.hovered && bar.spaces.length > 1 && bar.reveal === 1
                        color: Theme.color.material.thick.tint
                        border.width: 1
                        border.color: Theme.color.glass.edge

                        Repeater {
                            model: [45, -45]
                            Rectangle {
                                required property int modelData
                                anchors.centerIn: parent
                                width: Theme.space.s2 + 2
                                height: 1.5
                                radius: 1
                                rotation: modelData
                                color: Theme.color.label.primary
                                antialiasing: true
                            }
                        }

                        TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: bar.removed(space.index) }
                    }
                }

                Label {
                    id: name
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: (bar.closedHeight - height) / 2 * (1 - bar.reveal)
                        + (bar.pad + bar.shotHeight) * bar.reveal
                    height: bar.nameRow
                    text: space.modelData.name
                    style: Theme.text.callout
                    color: space.current || over.hovered ? Theme.color.label.primary : Theme.color.label.secondary
                    textFormat: Text.PlainText
                }

                HoverHandler { id: over }
                TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: bar.picked(space.index) }
            }
        }
    }

    // Another desktop.
    Item {
        id: plus

        anchors.right: parent.right
        anchors.rightMargin: Theme.space.s2
        width: Theme.size.mission.bar
        height: bar.height

        Rectangle {
            anchors.centerIn: parent
            width: Theme.space.s8 - Theme.space.s1
            height: width
            radius: Theme.radius.control
            color: adding.pressed ? Theme.color.fill.primary : overPlus.hovered ? Theme.color.fill.secondary : "transparent"

            Repeater {
                model: [0, 90]
                Rectangle {
                    required property int modelData
                    anchors.centerIn: parent
                    width: Theme.space.s3 + 2
                    height: 1.5
                    radius: 1
                    rotation: modelData
                    color: Theme.color.label.secondary
                }
            }
        }

        HoverHandler { id: overPlus }
        TapHandler { id: adding; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: bar.added() }
    }
}
