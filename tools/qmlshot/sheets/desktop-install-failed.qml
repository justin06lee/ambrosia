import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// The installation that couldn't finish.
Installing {
    steps: [() => { installer.failed = true; installer.page = "end"; }]
}
