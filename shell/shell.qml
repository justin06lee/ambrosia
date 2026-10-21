// The Ambrosia shell, run by Quickshell: on every screen a wallpaper, the
// menu bar, Search and a layer for menus and the control center; the Dock
// and notification banners on the first screen. Everything visual comes
// from the generated `Ambrosia` Theme module.
import Quickshell
import Quickshell.Io
import QtQuick
import Ambrosia

ShellRoot {
    // The installed shell doesn't reload itself when its files change:
    // pacman replaces them one at a time, and a reload partway through finds
    // no shell.qml and stays down. After an upgrade a pacman hook restarts it
    // instead (session/ambrosia-shell-restart). Run from a checkout, it still
    // reloads as you edit.
    settings.watchFiles: !Quickshell.shellDir.startsWith("/usr/")

    // The shell's look follows its settings.
    Binding { target: Theme; property: "dark"; value: Settings.dark }
    Binding { target: Theme; property: "accentName"; value: Settings.accent }

    // Our menus, the control center and Search take the keyboard, and with
    // it focus, from the app; the menu bar keeps showing the app meanwhile.
    Binding { target: Apps; property: "frozen"; value: Popups.kind !== "" || Popups.searchOpen }

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property ShellScreen modelData

            Wallpaper { screen: perScreen.modelData }
            MenuBar { screen: perScreen.modelData }
            Overlay { screen: perScreen.modelData; home: perScreen.modelData }
            Search { screen: perScreen.modelData; home: perScreen.modelData }
        }
    }

    Dock { screen: Quickshell.screens[0] ?? null }
    Notifications {}

    // `ambrosia search`, `ambrosia control-center` (see session/ambrosia):
    // what the keyboard shortcuts run.
    IpcHandler {
        target: "shell"

        function search(): void {
            Popups.toggleSearch(Quickshell.screens[0]);
        }
        function controlCenter(): void {
            Popups.toggleControlCenter(Quickshell.screens[0]);
        }
    }
}
