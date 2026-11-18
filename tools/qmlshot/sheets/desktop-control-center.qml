import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// The control center open.
Desk {
    then: () => Popups.toggleControlCenter(screen)
}
