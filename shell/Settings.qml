pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The shell's own settings, kept in ~/.local/state/quickshell/…/settings.json
// so they survive restarts. Changing one from QML writes the file.
Singleton {
    id: settings

    // Desktop file ids pinned to the Dock, in order. Pins for apps that
    // aren't installed are skipped.
    property alias dock: adapter.dock
    property alias dark: adapter.dark
    property alias accent: adapter.accent
    property alias doNotDisturb: adapter.doNotDisturb

    FileView {
        path: Quickshell.statePath("settings.json")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: settings.migrate()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property list<string> dock: [
                "org.ambrosia.files", "firefox", "org.kde.konsole", "org.kde.kate",
                "org.kde.gwenview", "org.kde.discover", "systemsettings",
            ]
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
    }
}
