import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// An app's own menu opened from the menu bar with the pointer, which then
// rests on a row that has a submenu.
Desk {
    then: () => {
        shotPointer.press(95, 14);
        shotPointer.release(95, 14);
        after.start();
    }
    Timer {
        id: after
        interval: 200
        onTriggered: shotPointer.move(140, 28 + 6 + 2.5 * 24)
    }
}
