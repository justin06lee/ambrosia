import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// Search open, with a few letters typed and the second result chosen.
Desk {
    then: () => {
        Popups.toggleSearch(screen);
        after.start();
    }
    Timer {
        id: after
        interval: 200
        onTriggered: {
            shotPointer.type("s");
            shotPointer.key(Qt.Key_Down);
        }
    }
}
