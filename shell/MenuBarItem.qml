import Quickshell
import QtQuick
import Ambrosia

// One menu bar entry: a title or an icon on a capsule that lights on hover
// and while its menu is open. With a `menu` (a list of MenuView entries, a
// function returning one, or an app's QsMenuHandle) it opens that menu on
// press; without one it just emits pressed().
Item {
    id: item

    property string owner
    property var menu: null
    property string text
    property string icon
    property real iconSize: Theme.size.menubar.icon
    property real iconOpacity: 1
    property bool bold
    property bool active: Popups.menuOpen && Popups.owner === owner && Popups.screen === QsWindow.window?.screen
    property real padding: icon ? 7 : Theme.size.menubar.itemPadding
    signal pressed

    implicitHeight: 22
    implicitWidth: (icon ? iconSize : label.implicitWidth) + 2 * padding

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.color.fill.primary
        opacity: area.containsMouse || item.active ? 1 : 0
        // Lights at once while a menu is open, so switching titles is crisp.
        Behavior on opacity {
            enabled: !Popups.menuOpen
            NumberAnimation { duration: Theme.fade.fast; easing.type: Easing.BezierSpline; easing.bezierCurve: [...Theme.fade.curve, 1, 1] }
        }
    }

    Label {
        id: label
        visible: !item.icon
        anchors.centerIn: parent
        text: item.text
        style: item.bold ? Theme.text.headline : Theme.text.body
        font.features: ({ "tnum": 1 })
    }

    Icon {
        visible: !!item.icon
        anchors.centerIn: parent
        name: item.icon
        size: item.iconSize
        opacity: item.iconOpacity
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onPressed: {
            if (item.menu) QsWindow.window.openFor(item, true);
            else item.pressed();
        }
        // With a menu open, the title under the pointer opens its own.
        onEntered: {
            if (item.menu && Popups.menuOpen && Popups.owner !== item.owner && Popups.screen === QsWindow.window.screen)
                QsWindow.window.openFor(item, false);
        }
    }
}
