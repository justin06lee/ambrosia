import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// Create Your Account: a name typed, its account name following it, passwords that don't match yet.
Installing {
    steps: [() => shotPointer.key(Qt.Key_Return), () => shotPointer.key(Qt.Key_Return), () => shotPointer.type("Mina Park"),
        () => shotPointer.key(Qt.Key_Tab), () => shotPointer.key(Qt.Key_Tab), () => shotPointer.type("nectar"),
        () => shotPointer.key(Qt.Key_Tab), () => shotPointer.type("nect")]
}
