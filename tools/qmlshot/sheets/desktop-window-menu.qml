import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// Where a window can go: the menu the green light of a window's frame brings
// up when the pointer rests on it (`ambrosia window-menu`), the pointer on
// its first row.
Desk {
    then: () => {
        Popups.openMenu(Quickshell.screens[0], "places", Apps.placeEntries(Apps.focusedWindow()).concat([
            { separator: true },
            { text: "Center", action: () => {} },
            { text: "Enter Full Screen", action: () => {} },
        ]), 60, 80);
        after.start();
    }
    Timer {
        id: after
        interval: 200
        onTriggered: shotPointer.move(110, 80 + 6 + 12)
    }
}
