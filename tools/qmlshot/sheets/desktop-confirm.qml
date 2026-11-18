import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// A confirmation.
Desk {
    then: () => bar.ambrosiaMenu()[8].action()
}
