pragma Singleton
import Quickshell
import QtQuick

// What transient UI is open, and on which screen: menus, the control center,
// a confirmation, the notification center, the search window. Each screen's Overlay draws whatever is
// open on it; only one thing is open at a time.
Singleton {
    id: popups

    // "" (nothing), "menu", "controlCenter", "notificationCenter", "stack",
    // "forceQuit", "emoji" or "confirm".
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
    // The Dock stack that is open, while kind is "stack" (see toggleStack).
    property var stack: null

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

    // A Dock stack: { folder, edge: the Dock's side of the screen, x, y: the
    // point of the Overlay's frame the grid grows away from }.
    function toggleStack(screen, stack) {
        if (kind === "stack") {
            close();
            return;
        }
        searchOpen = false;
        popups.screen = screen;
        owner = "dock";
        levels = [];
        popups.stack = stack;
        kind = "stack";
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

    function toggleNotificationCenter(screen) {
        if (kind === "notificationCenter") {
            close();
            return;
        }
        searchOpen = false;
        popups.screen = screen;
        owner = "notificationCenter";
        levels = [];
        kind = "notificationCenter";
    }

    function confirm(screen, confirmation) {
        // Taking its place refuses the one before.
        const before = refusal;
        refusal = null;
        searchOpen = false;
        popups.screen = screen;
        popups.confirmation = confirmation;
        owner = "";
        levels = [];
        kind = "confirm";
        refusal = confirmation.cancel ?? null;
        if (before) before();
    }

    // A confirmation may say what to do when it is put away unanswered
    // (`cancel`): by its Cancel, Escape, a click beside it, or something
    // else opening in its place.
    property var refusal: null
    onKindChanged: {
        const refuse = refusal;
        refusal = null;
        if (refuse) refuse();
    }
    // One that stays up after its button is pressed (`hold`) is told its
    // answer was wrong, and shakes, or is put away by whoever opened it.
    signal refused()
    function finish() {
        if (kind !== "confirm") return;
        refusal = null;
        close();
    }

    // Force Quit Applications (ForceQuit.qml).
    function toggleForceQuit(screen) {
        if (kind === "forceQuit") {
            close();
            return;
        }
        searchOpen = false;
        popups.screen = screen;
        owner = "";
        levels = [];
        kind = "forceQuit";
    }

    // The emoji picker (EmojiPicker.qml).
    function toggleEmoji(screen) {
        if (kind === "emoji") {
            close();
            return;
        }
        searchOpen = false;
        popups.screen = screen;
        owner = "";
        levels = [];
        kind = "emoji";
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
        stack = null;
    }
}
