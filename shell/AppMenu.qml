import Quickshell
import Quickshell.DBusMenu
import QtQuick

// The focused app's own menus, as it publishes them over DBus: its top-level
// entries (File, Edit, ...) in `entries`. A file of its own, loaded by the
// menu bar, because DBusMenuSource comes from our Quickshell build: on a
// Quickshell without it only this fails, and the bar keeps its own menus.
// Loaded by path, it doesn't share the shell's singletons, so the menu bar
// passes in where the menu is.
Item {
    id: appMenu

    property string service
    property string path
    readonly property var entries: opener.children.values

    DBusMenuSource {
        id: source
        service: appMenu.service
        path: appMenu.path
    }
    QsMenuOpener {
        id: opener
        menu: appMenu.service && appMenu.path ? source : null
    }
}
