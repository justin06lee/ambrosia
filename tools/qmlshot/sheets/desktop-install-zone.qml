import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// Select Your Time Zone: the guessed one chosen, the list searched.
Installing {
    steps: [() => shotPointer.key(Qt.Key_Return), () => shotPointer.key(Qt.Key_Return), () => shotPointer.type("Mina Park"),
        () => shotPointer.key(Qt.Key_Tab), () => shotPointer.key(Qt.Key_Tab), () => shotPointer.type("nectar"),
        () => shotPointer.key(Qt.Key_Tab), () => shotPointer.type("nectar"), () => shotPointer.key(Qt.Key_Return), () => shotPointer.type("a")]
}
