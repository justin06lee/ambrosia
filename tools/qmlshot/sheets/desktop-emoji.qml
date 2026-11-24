import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// The emoji picker open (⌃⌘Space), the second line's third emoji chosen.
Desk {
    then: () => {
        Popups.toggleEmoji(screen);
        after.start();
    }
    Timer {
        id: after
        interval: 200
        onTriggered: {
            shotPointer.key(Qt.Key_Down);
            shotPointer.key(Qt.Key_Right);
            shotPointer.key(Qt.Key_Right);
        }
    }
}
