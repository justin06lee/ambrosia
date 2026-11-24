import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// With no internet: the Wi-Fi networks in reach, one chosen and its password asked for.
Installing {
    offline: true
    steps: [() => shotPointer.key(Qt.Key_Return), () => shotPointer.key(Qt.Key_Down), () => shotPointer.type("nectar")]
}
