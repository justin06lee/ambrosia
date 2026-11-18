import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// The Ambrosia menu, as the Apple menu is.
Desk {
    then: () => bar.openFor(bar.menuItems()[0], false)
}
