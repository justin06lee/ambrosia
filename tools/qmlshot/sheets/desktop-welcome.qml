import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// A new account's welcome, as its first login shows it.
Desk {
    then: () => Popups.welcomeOpen = true
}
