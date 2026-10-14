pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The shell's own settings, kept in ~/.local/state/quickshell/…/settings.json
// so they survive restarts. Changing one from QML writes the file.
Singleton {
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
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property list<string> dock: [
                "org.kde.dolphin", "firefox", "org.kde.konsole", "org.kde.kate",
                "org.kde.gwenview", "org.kde.discover", "systemsettings",
            ]
            property bool dark: false
            property string accent: "blue"
            property bool doNotDisturb: false
        }
    }
}
