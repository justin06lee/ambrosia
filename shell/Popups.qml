pragma Singleton
import Quickshell
import QtQuick

// What transient UI is open, and on which screen: menus, the control center,
// a confirmation, the search window. Each screen's Overlay draws whatever is
// open on it; only one thing is open at a time.
Singleton {
    id: popups

    // "" (nothing), "menu", "controlCenter" or "confirm".
    property string kind: ""
    property ShellScreen screen: null

    // Open menus, outermost first: { entries | build | handle, x, y }, with x
    // and y relative to the screen. `entries` is a list of plain items (see
    // MenuView); `build` a function returning one, re-run while the menu is
    // open as what it reads changes (the Wi-Fi networks); `handle` an app's
    // own menu (QsMenuHandle).
    property var levels: []
    // The menu bar title or Dock app whose menu is open.
    property string owner: ""

    // The open confirmation: { title, text, accept, action }.
    property var confirmation: null

    property bool searchOpen: false
    property ShellScreen searchScreen: null

    readonly property bool menuOpen: kind === "menu"

    // Left or right arrow in an open menu: the menu bar opens its neighbor.
    signal step(int direction)

    function levelFor(source) {
        if (typeof source === "function") return { build: source };
        return Array.isArray(source) ? { entries: source } : { handle: source };
    }

    function openMenu(screen, owner, source, x, y) {
        const level = levelFor(source);
        level.x = x;
        level.y = y;
        searchOpen = false;
        popups.screen = screen;
        popups.owner = owner;
        levels = [level];
        kind = "menu";
    }
    // Opens a submenu beside the row that holds it, closing deeper ones.
    function openSubmenu(depth, source, x, y, fromKeyboard) {
        const level = levelFor(source);
        level.x = x;
        level.y = y;
        level.fromKeyboard = fromKeyboard;
        levels = levels.slice(0, depth + 1).concat([level]);
    }
    function closeSubmenus(depth) {
        if (levels.length > depth + 1) levels = levels.slice(0, depth + 1);
    }

    function toggleControlCenter(screen) {
        if (kind === "controlCenter") {
            close();
            return;
        }
        searchOpen = false;
        popups.screen = screen;
        owner = "controlCenter";
        levels = [];
        kind = "controlCenter";
    }

    function confirm(screen, confirmation) {
        searchOpen = false;
        popups.screen = screen;
        popups.confirmation = confirmation;
        owner = "";
        levels = [];
        kind = "confirm";
    }

    function toggleSearch(screen) {
        if (searchOpen) {
            searchOpen = false;
            return;
        }
        close();
        searchScreen = screen ?? Quickshell.screens[0];
        searchOpen = true;
    }

    function close() {
        kind = "";
        owner = "";
        levels = [];
        confirmation = null;
    }
}
