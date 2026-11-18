import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// An app's menu in the Dock, opened with the right button.
Desk {
    then: () => {
        shotPointer.click(534, 852, Qt.RightButton);
        after.start();
    }
    Timer {
        id: after
        interval: 200
        onTriggered: shotPointer.move(534, 720)
    }
}
