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
    // What the menu bar calls the app (its Quit may be "Quit Kate").
    property string appName
    readonly property var entries: opener.children.values

    // The rows a Mac keeps in the menu named for the app, found in the app's
    // own menus as Qt finds them when it runs on a Mac, by what they say:
    // its About, its settings and its Quit. The menu bar shows them in its
    // app menu and leaves them out where the app put them. Only rows right
    // under a title are looked at, read from what the app has already sent
    // (`loadedChildren`, from our Quickshell): opening each menu to look
    // would tell the app its menus were open.
    readonly property var lifted: {
        const found = { about: null, settings: null, quit: null };
        // KDE's "Configure …" rows that are not the app's own settings; the
        // app's own comes last of them.
        const other = /^Configure (Keyboard |Custom |Global )?(Shortcuts|Toolbars|Notifications|Language|Extensions|Spell)/i;
        let named = false;
        for (const top of appMenu.entries) {
            for (const row of top?.loadedChildren?.values ?? []) {
                if (!row || row.isSeparator || row.hasChildren) continue;
                const text = (row.text ?? "").trim();
                if (/^About /i.test(text) && !/^About (KDE|Qt|GNOME)$/i.test(text)) {
                    if (!found.about) found.about = row;
                } else if (/^(Preferences|Settings|Options)\s*(…|\.\.\.)?$/i.test(text)) {
                    if (!named) found.settings = row;
                    named = true;
                } else if (!named && /^Configure \S.*(…|\.\.\.)$/i.test(text) && !other.test(text)) {
                    found.settings = row;
                } else if (/^(Quit|Exit)$/i.test(text) || (appMenu.appName && text === `Quit ${appMenu.appName}`)) {
                    if (!found.quit) found.quit = row;
                }
            }
        }
        return found;
    }

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
