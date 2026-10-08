// The Ambrosia shell, run by Quickshell: a wallpaper and a menu bar on every
// screen. Everything visual comes from the generated `Ambrosia` Theme module.
import Quickshell
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property ShellScreen modelData

            Wallpaper { screen: perScreen.modelData }
            MenuBar { screen: perScreen.modelData }
        }
    }
}
