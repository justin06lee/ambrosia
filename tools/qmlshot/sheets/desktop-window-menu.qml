import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// The menu bar's Window menu with Move & Resize open beside it: where a
// window can go. The green light of a window's frame brings up the same
// rows when the pointer rests on it (`ambrosia window-menu`).
Desk {
    then: () => {
        Popups.openMenu(Quickshell.screens[0], "Window", bar.windowMenu(), 300, 0);
        after.start();
    }
    Timer {
        id: after
        interval: 200
        onTriggered: shotPointer.move(380, 28 + 6 + 3 * 24 + 13 + 12)
    }
}
