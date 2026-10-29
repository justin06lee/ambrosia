pragma Singleton
import QtQuick
import Settings

// The panes, in macOS 26's order, keeping what maps to this system
// (docs/settings/PLAN.md): the sidebar's groups and the pages inside them.
// A pane is shown once it is ours (`page`) or, until then, once KDE's
// module for it (`module`) is installed, which opens in its own window;
// one with neither isn't listed, so no row is dead.
QtObject {
    id: panes

    // Each: id, name, glyph (glyphs.js), tint (Look.tints), keywords for
    // the search, and page or module.
    readonly property var groups: [
        [
            { id: "wifi", name: "Wi‑Fi", glyph: "wifi", tint: "blue", page: "wifi", device: "wifi",
              keywords: ["wireless", "network", "internet", "hotspot", "join"] },
            { id: "bluetooth", name: "Bluetooth", glyph: "bluetooth", tint: "blue", page: "bluetooth", device: "bluetooth",
              keywords: ["devices", "pair", "headphones", "wireless"] },
            { id: "network", name: "Network", glyph: "network", tint: "blue", module: "kcm_networkmanagement",
              keywords: ["ethernet", "vpn", "dns", "proxy", "ip", "internet"] },
            { id: "battery", name: App.hasBattery ? "Battery" : "Energy", glyph: App.hasBattery ? "battery" : "energy",
              tint: "green", module: "kcm_powerdevilprofilesconfig",
              keywords: ["power", "low power mode", "sleep", "energy", "battery"] },
        ],
        [
            { id: "general", name: "General", glyph: "general", tint: "gray", page: "general",
              description: "Manage your overall setup and preferences for this computer, such as software updates, the date, language and login items.",
              keywords: ["about", "software update", "date", "time", "language", "region", "login items"] },
            { id: "accessibility", name: "Accessibility", glyph: "accessibility", tint: "blue", module: "kcm_access",
              keywords: ["zoom", "sticky keys", "slow keys", "bounce keys", "bell"] },
            { id: "appearance", name: "Appearance", glyph: "appearance", tint: "black",
              keywords: ["dark", "light", "accent", "theme", "color"] },
            { id: "dock", name: "Desktop & Dock", glyph: "dock", tint: "black",
              keywords: ["dock", "hot corners", "windows", "minimize"] },
            { id: "displays", name: "Displays", glyph: "displays", tint: "blue", module: "kcm_kscreen",
              keywords: ["resolution", "monitor", "scale", "refresh rate", "arrangement", "night shift"] },
            { id: "menubar", name: "Menu Bar", glyph: "menubar", tint: "gray",
              keywords: ["control center", "menu bar", "clock"] },
            { id: "spotlight", name: "Spotlight", glyph: "spotlight", tint: "blue",
              keywords: ["search"] },
            { id: "wallpaper", name: "Wallpaper", glyph: "wallpaper", tint: "cyan",
              keywords: ["background", "desktop picture"] },
        ],
        [
            { id: "notifications", name: "Notifications", glyph: "notifications", tint: "red",
              keywords: ["alerts", "banners", "badges"] },
            { id: "sound", name: "Sound", glyph: "sound", tint: "pink", page: "sound",
              keywords: ["volume", "output", "input", "microphone", "speakers", "alert"] },
            { id: "focus", name: "Focus", glyph: "focus", tint: "indigo",
              keywords: ["do not disturb"] },
        ],
        [
            { id: "lockscreen", name: "Lock Screen", glyph: "lockscreen", tint: "black", module: "kcm_screenlocker",
              keywords: ["lock", "screen saver", "password", "sleep"] },
            { id: "privacy", name: "Privacy & Security", glyph: "privacy", tint: "blue",
              keywords: ["camera", "microphone", "screen recording", "permissions"] },
            { id: "password", name: "Login Password", glyph: "password", tint: "gray", module: "kcm_users",
              keywords: ["password", "change password"] },
            { id: "users", name: "Users & Groups", glyph: "users", tint: "blue", module: "kcm_users",
              keywords: ["accounts", "user", "administrator", "picture"] },
        ],
        [
            { id: "keyboard", name: "Keyboard", glyph: "keyboard", tint: "gray", module: "kcm_keyboard",
              keywords: ["key repeat", "input sources", "layout", "shortcuts"] },
            { id: "mouse", name: "Mouse", glyph: "mouse", tint: "gray", module: "kcm_mouse", device: "mouse",
              keywords: ["pointer", "tracking speed", "scrolling", "click"] },
            { id: "trackpad", name: "Trackpad", glyph: "trackpad", tint: "gray", module: "kcm_touchpad", device: "trackpad",
              keywords: ["tap to click", "tracking speed", "scrolling", "gestures"] },
            { id: "printers", name: "Printers & Scanners", glyph: "printer", tint: "gray",
              keywords: ["print", "printer"] },
        ],
    ]

    // General's pages, in the order System Settings lists them.
    readonly property var general: [
        [
            { id: "about", name: "About", glyph: About.laptop ? "laptop" : "desktop", tint: "gray", page: "about" },
            { id: "softwareupdate", name: "Software Update", glyph: "update", tint: "gray", module: "kcm_updates",
              keywords: ["update", "upgrade", "packages"] },
            { id: "storage", name: "Storage", glyph: "storage", tint: "gray", keywords: ["disk", "space"] },
        ],
        [
            { id: "datetime", name: "Date & Time", glyph: "datetime", tint: "blue", module: "kcm_clock",
              keywords: ["clock", "time zone", "24-hour"] },
            { id: "language", name: "Language & Region", glyph: "language", tint: "blue", module: "kcm_regionandlang",
              keywords: ["language", "region", "formats", "calendar"] },
            { id: "loginitems", name: "Login Items", glyph: "loginitems", tint: "gray", module: "kcm_autostart",
              keywords: ["startup", "autostart", "login"] },
            { id: "sharing", name: "Sharing", glyph: "loginitems", tint: "gray", keywords: ["computer name", "remote login"] },
        ],
    ]
    // The pages a pane holds, by its id, and the pane each page is in.
    readonly property var children: ({ general: general })
    readonly property var parentOf: {
        const map = {};
        for (const id of Object.keys(children))
            for (const group of children[id])
                for (const pane of group)
                    map[pane.id] = id;
        return map;
    }
    // A pane the app doesn't list: the controls, side by side with System
    // Settings' (--pane controls).
    readonly property var hidden: [{ id: "controls", name: "Controls", glyph: "general", tint: "gray", page: "controls" }]

    function available(pane) {
        if (pane.device === "mouse" && !App.hasMouse)
            return false;
        if (pane.device === "trackpad" && !App.hasTrackpad)
            return false;
        if (pane.device === "wifi" && !WiFi.available)
            return false;
        if (pane.device === "bluetooth" && !Bluetooth.available)
            return false;
        return pane.page !== undefined || (pane.module !== undefined && App.hasModule(pane.module));
    }
    function find(id) {
        for (const list of [groups, general, [hidden]])
            for (const group of list)
                for (const pane of group)
                    if (pane.id === id)
                        return pane;
        return null;
    }
    // Whether a pane, or a page inside it, answers the search.
    function matches(pane, text) {
        const words = text.trim().toLowerCase();
        if (words === "")
            return true;
        const own = [pane.name].concat(pane.keywords ?? []).some(k => k.toLowerCase().includes(words));
        return own || (children[pane.id] ?? []).some(group => group.some(page => available(page) && matches(page, text)));
    }
    // The sidebar's groups, each the panes shown that answer the search.
    function listed(text) {
        return groups.map(group => group.filter(pane => available(pane) && matches(pane, text))).filter(group => group.length > 0);
    }
}
