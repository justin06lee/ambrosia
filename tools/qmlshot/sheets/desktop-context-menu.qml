import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// The right button on the desktop: its menu at the pointer, which then
// rests on the first row.
Desk {
    then: () => {
        shotPointer.press(520, 360, Qt.RightButton);
        shotPointer.release(520, 360, Qt.RightButton);
        after.start();
    }
    Timer {
        id: after
        interval: 200
        onTriggered: shotPointer.move(560, 360 + 6 + 12)
    }
}
