import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// Choose a Disk: the second of two chosen by the arrow key.
Installing {
    steps: [() => shotPointer.key(Qt.Key_Return), () => shotPointer.key(Qt.Key_Right)]
}
