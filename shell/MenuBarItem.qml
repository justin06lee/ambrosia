import QtQuick
import Ambrosia

// One menu bar entry: a title or an icon on a capsule that lights on hover.
Item {
    id: item

    property string text
    property string icon
    property real iconSize: Theme.size.menubar.icon
    property bool bold
    property bool active
    property real padding: icon ? 7 : Theme.size.menubar.itemPadding
    signal clicked

    implicitHeight: 22
    implicitWidth: (icon ? iconSize : label.implicitWidth) + 2 * padding

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.color.fill.primary
        opacity: hover.hovered || item.active ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.fade.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: [...Theme.fade.curve, 1, 1] }
        }
    }

    Label {
        id: label
        visible: !item.icon
        anchors.centerIn: parent
        text: item.text
        style: item.bold ? Theme.text.headline : Theme.text.body
    }

    Icon {
        visible: !!item.icon
        anchors.centerIn: parent
        name: item.icon
        size: item.iconSize
    }

    HoverHandler { id: hover }
    TapHandler { onTapped: item.clicked() }
}
