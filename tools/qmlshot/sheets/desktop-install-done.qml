import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// Ambrosia Is Installed: the offer to restart.
Installing {
    steps: [() => { installer.page = "end"; }]
}
