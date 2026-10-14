import Quickshell
import Quickshell.Wayland
import QtQuick
import Ambrosia

// A screen's layer for transient UI: menus, the control center and
// confirmations. While something is open it covers the screen below the menu
// bar, so a click anywhere else closes it and goes no further, as on a Mac.
// The menu bar stays uncovered, so moving along its titles switches menus.
PanelWindow {
    id: overlay

    // The screen this window was made for (its live `screen` changes as it
    // maps and unmaps, which would loop through `visible`).
    required property ShellScreen home
    readonly property bool active: Popups.kind !== "" && Popups.screen === home

    // Up while something is open, and while the control center fades out.
    visible: active || controlCenter.shown
    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: Theme.size.menubar.height
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ambrosia-overlay"
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
            x: !level ? 0 : Math.max(0, level.x + width > overlay.width && index > 0
                ? menus.itemAt(index - 1).x - width + padding
                : Math.min(level.x, overlay.width - width))
            y: !level ? 0 : Math.max(0, Math.min(level.y - (index > 0 ? padding : 0), overlay.height - height))

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
