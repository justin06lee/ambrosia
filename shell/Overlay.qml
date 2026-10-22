import Quickshell
import Quickshell.Wayland
import QtQuick
import Ambrosia

// A screen's layer for transient UI: menus, the control center and
// confirmations. While something is open it covers the screen below the menu
// bar, so a click anywhere else closes it and goes no further, as on a Mac.
// The menu bar stays uncovered, so moving along its titles switches menus.
//
// It is a grabbing popup of the menu bar rather than a layer of its own: KWin
// sends a grabbing popup the keys without activating it, so the app's window
// stays active while a menu is open, as a Mac keeps it key. A layer surface
// that takes the keyboard becomes KWin's active window instead.
PopupWindow {
    id: overlay

    // The screen this window was made for (its live `screen` changes as it
    // maps and unmaps, which would loop through `visible`), and its menu bar.
    required property ShellScreen home
    required property PanelWindow bar
    readonly property bool active: Popups.kind !== "" && Popups.screen === home

    // Up while something is open, and while the control center fades out.
    visible: active || controlCenter.shown
    // KWin closes a grabbing popup on its own, as when another window
    // activates; whatever was open on it closes too.
    onVisibleChanged: if (!visible && active) Popups.close()
    grabFocus: true
    // It spans the whole screen, menu bar included: Qt hands the popup the
    // menu bar's pointer events first, by screen position, and a popup that
    // began below the bar would take a press on a title for one on a menu
    // row. Over the bar it takes no input and holds nothing, so the bar
    // under it works as before.
    anchor.window: bar
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.adjustment: PopupAdjustment.None
    implicitWidth: home.width
    implicitHeight: home.height
    mask: Region { item: area }
    color: "transparent"

    BackgroundEffect.blurRegion: Region {
        regions: {
            const list = [];
            for (let i = 0; i < Popups.levels.length; i++) {
                const menu = menus.itemAt(i);
                if (menu?.visible) list.push(menu.blurArea);
            }
            if (controlCenter.shown) list.push(controlCenter.blurArea);
            if (confirm.visible) list.push(confirm.blurArea);
            return list;
        }
    }

    // Everything below the menu bar.
    Item {
        id: area
        y: Theme.size.menubar.height
        width: overlay.width
        height: overlay.height - y

        // A click outside whatever is open closes it.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: Popups.close()
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: overlay.active

            Keys.onPressed: event => {
                const depth = Popups.menuOpen ? Popups.levels.length : 0;
                const menu = depth > 0 ? menus.itemAt(depth - 1) : null;
                switch (event.key) {
                case Qt.Key_Escape:
                    if (depth > 1) Popups.closeSubmenus(depth - 2);
                    else Popups.close();
                    break;
                case Qt.Key_Up:
                    menu?.move(-1);
                    break;
                case Qt.Key_Down:
                    menu?.move(1);
                    break;
                case Qt.Key_Right:
                    if (menu && !menu.openCurrent()) Popups.step(1);
                    break;
                case Qt.Key_Left:
                    if (depth > 1) Popups.closeSubmenus(depth - 2);
                    else if (depth === 1) Popups.step(-1);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:
                    if (menu) menu.activateCurrent();
                    else if (confirm.visible) confirm.accept();
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }
        }

        // A slot per menu depth. A slot changes only when its own menu does, so
        // opening a submenu leaves the menus around it as they are.
        Repeater {
            id: menus
            model: 4

            MenuView {
                id: slot
                required property int index
                property var level: null
                readonly property Region blurArea: Region { item: slot; radius: Theme.radius.popover }

                visible: level !== null && overlay.active && Popups.kind === "menu"
                depth: index
                entries: level?.build ? level.build() : (level?.entries ?? [])
                handle: level?.handle ?? null
                // Kept on screen; a submenu with no room on the right opens on the left.
                x: !level ? 0 : Math.max(0, level.x + width > area.width && index > 0
                    ? menus.itemAt(index - 1).x - width + padding
                    : Math.min(level.x, area.width - width))
                y: !level ? 0 : Math.max(0, Math.min(level.y - (index > 0 ? padding : 0), area.height - height))

                Connections {
                    target: Popups
                    function onLevelsChanged() {
                        const level = Popups.levels[slot.index] ?? null;
                        if (level === slot.level) return;
                        slot.current = -1;
                        slot.level = level;
                        // A submenu opened from the keyboard starts on its first row.
                        if (level?.fromKeyboard) Qt.callLater(() => slot.move(1));
                    }
                }
            }
        }

        ControlCenter {
            id: controlCenter
            open: overlay.active && Popups.kind === "controlCenter"
            anchors { top: parent.top; right: parent.right; topMargin: Theme.space.s1_5; rightMargin: Theme.space.s2 }
        }

        ConfirmDialog {
            id: confirm
            visible: overlay.active && Popups.kind === "confirm"
            confirmation: Popups.confirmation
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -parent.height / 6
        }
    }
}
