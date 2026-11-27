import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// The bold menu named for the app in front: the app's own About and
// settings, lifted from its menus, then Hide, Hide Others, Show All (the
// session's KWin effect does the hiding) and Quit.
Desk {
    then: () => {
        shotPointer.press(40, 14);
        shotPointer.release(40, 14);
        after.start();
    }
    Timer {
        id: after
        interval: 200
        onTriggered: shotPointer.move(70, 28 + 6 + 12)
    }
}
