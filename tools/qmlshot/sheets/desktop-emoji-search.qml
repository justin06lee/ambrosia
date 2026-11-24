import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// The emoji picker with a word typed: what it finds, best first.
Desk {
    then: () => {
        Popups.toggleEmoji(screen);
        after.start();
    }
    Timer {
        id: after
        interval: 200
        onTriggered: shotPointer.type("cat")
    }
}
