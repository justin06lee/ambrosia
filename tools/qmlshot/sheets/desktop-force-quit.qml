import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// Force Quit Applications, from the Ambrosia menu.
Desk {
    then: () => bar.ambrosiaMenu()[4].action()
}
