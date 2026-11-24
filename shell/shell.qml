// The Ambrosia shell, run by Quickshell: on every screen a wallpaper, the
// menu bar, Search and a layer for menus and the control center; the Dock,
// notification banners and the volume and brightness keys' display on the
// first screen. Everything visual comes
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
    // Up from the start: it applies them and follows the night.
    readonly property bool nightLight: Appearance.nightLight

    // Search takes the keyboard, and with it focus, from the app; menus keep
    // the app active, but its window may change under them. Either way the
    // menu bar keeps showing the app it opened on.
    Binding { target: Apps; property: "frozen"; value: Popups.kind !== "" || Popups.searchOpen }

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property ShellScreen modelData

            Wallpaper { screen: perScreen.modelData }
            MenuBar { id: bar; screen: perScreen.modelData }
            Overlay { home: perScreen.modelData; bar: bar }
            Search { screen: perScreen.modelData; home: perScreen.modelData }
        }
    }

    // Made afresh when the first screen changes, as the menu bar is above: a
    // window whose screen went away doesn't come back on its own.
    Variants {
        model: Quickshell.screens.slice(0, 1)

        Dock {
            required property ShellScreen modelData
            screen: modelData
        }
    }
    // A new account's first minutes: a welcome, and the look it wants.
    Variants {
        model: Quickshell.screens.slice(0, 1)

        Welcome {
            required property ShellScreen modelData
            home: modelData
        }
    }
    // Install Ambrosia: the live image's assistant.
    Variants {
        model: Quickshell.screens.slice(0, 1)

        Installer {
            required property ShellScreen modelData
            home: modelData
        }
    }
    Notifications {}
    // What the volume and brightness keys show.
    Hud {}
    // ⇧⌘3 and ⇧⌘4: the picture to the Desktop, its thumbnail in the corner.
    Screenshot { id: shots }
    // Which keyboard layer the focused app gets (the Mac-first keyboard).
    KeyLayer {}

    // Programs' requests for the password (polkit).
    Authorization {}

    // `ambrosia search`, `ambrosia control-center`, `ambrosia force-quit`
    // and the rest (see session/ambrosia): what the keyboard shortcuts run.
    IpcHandler {
        target: "shell"

        function search(): void {
            Popups.toggleSearch(Quickshell.screens[0]);
        }
        function controlCenter(): void {
            Popups.toggleControlCenter(Quickshell.screens[0]);
        }
        function notificationCenter(): void {
            Popups.toggleNotificationCenter(Quickshell.screens[0]);
        }
        function forceQuit(): void {
            Popups.toggleForceQuit(Quickshell.screens[0]);
        }
        // ⌃⌘Space: the emoji picker, on the screen the app in front is on.
        function emoji(): void {
            Popups.toggleEmoji(Quickshell.screens[0]);
        }
        // The welcome a new account gets, again.
        function welcome(): void {
            Popups.welcomeOpen = true;
        }
        // Install Ambrosia (the live image's /usr/local/bin/ambrosia-install asks).
        function install(): void {
            Popups.installerOpen = true;
        }
        // ⌘Q for an app with no Quit of its own on Ctrl+Q: every window of
        // the app in front is asked to close.
        function quit(): void {
            if (Apps.activeRow >= 0) Apps.quit(Apps.activeRow);
        }
        function screenshot(kind: string): void {
            shots.take(kind);
        }
        // The green light of a window's frame, with the pointer resting on
        // it: where that window can go, as a menu under the light. (Menus
        // open in the Overlay's frame, which starts below the menu bar.)
        function windowMenu(x: int, y: int): void {
            const window = Apps.focusedWindow();
            const screen = Quickshell.screens.find(s => x >= s.x && x < s.x + s.width && y >= s.y && y < s.y + s.height) ?? Quickshell.screens[0];
            Popups.openMenu(screen, "places", Apps.placeEntries(window).concat([
                { separator: true },
                { text: "Center", action: () => Apps.placeWindow(window, "Window Move Center") },
                { text: "Enter Full Screen", action: () => Apps.fullScreenWindow(window) },
            ]), x - screen.x, y - screen.y - Theme.size.menubar.height);
        }
    }
}
