pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The shell's settings, kept in ~/.config/ambrosia/settings.json, which the
// Settings app reads and writes too: a change from either reaches the other.
// Changing one from QML writes the file, dropping any key not declared here.
Singleton {
    id: settings

    // Desktop file ids pinned to the Dock, in order. Pins for apps that
    // aren't installed are skipped.
    property alias dock: adapter.dock
    // "auto", "light" or "dark"; dark is what it comes to (Appearance.qml).
    property alias appearance: adapter.appearance
    property alias dark: adapter.dark
    property alias accent: adapter.accent
    property alias doNotDisturb: adapter.doNotDisturb
    // Read once: from here on, a change is one somebody made.
    property bool loaded: false

    // Where they were before: the first start here takes them from there.
    FileView {
        id: before
        path: Quickshell.statePath("settings.json")
        blockAllReads: true
        printErrors: false
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/ambrosia/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            settings.migrate();
            Qt.callLater(() => settings.loaded = true);
        }
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound)
                return;
            const old = before.text();
            if (old)
                setText(old);
            else
                writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property list<string> dock: [
                "org.ambrosia.files", "firefox", "org.kde.konsole", "org.kde.kate",
                "org.kde.gwenview", "org.kde.discover", "org.ambrosia.settings",
            ]
            property string appearance: "light"
            property bool dark: false
            property string accent: "blue"
            property bool doNotDisturb: false
            // How many of migrate()'s steps this file has been through.
            property int migrated: 0
        }
    }

    // Brings settings an older shell wrote up to date, each step once.
    function migrate() {
        if (adapter.migrated < 1) {
            // Files took over from Dolphin as the Dock's file manager.
            if (!adapter.dock.includes("org.ambrosia.files"))
                adapter.dock = adapter.dock.map(id => id === "org.kde.dolphin" ? "org.ambrosia.files" : id);
            adapter.migrated = 1;
        }
        if (adapter.migrated < 2) {
            // Our Settings took over from KDE's; the file gained appearance.
            adapter.dock = adapter.dock.map(id => id === "systemsettings" ? "org.ambrosia.settings" : id);
            adapter.appearance = adapter.dark ? "dark" : "light";
            adapter.migrated = 2;
        }
    }
}
