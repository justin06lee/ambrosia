import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// Installing: the bar part of the way (the install itself never starts here).
Installing {
    steps: [() => shotPointer.key(Qt.Key_Return), () => shotPointer.key(Qt.Key_Return), () => shotPointer.type("Mina Park"),
        () => shotPointer.key(Qt.Key_Tab), () => shotPointer.key(Qt.Key_Tab), () => shotPointer.type("nectar"),
        () => shotPointer.key(Qt.Key_Tab), () => shotPointer.type("nectar"), () => shotPointer.key(Qt.Key_Return), () => shotPointer.key(Qt.Key_Return), () => shotPointer.key(Qt.Key_Return),
        () => { installer.fraction = 0.62; installer.doing = "Installing the system…"; }]
}
