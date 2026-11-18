import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// A banner arriving from an app whose icon isn't ours (on a plain tile), one
// from an app of ours, and one that waits for an answer.
Desk {
    then: () => {
        const server = NotificationStore.server;
        server.shotNotify({ appName: "Post", appIcon: "other-app", summary: "Ada Lovelace", body: "The notes from Tuesday are in the shared folder now." });
        server.shotNotify({ appName: "Discover", desktopEntry: "org.kde.discover", summary: "Updates Available", body: "12 packages can be updated." });
        server.shotNotify({ appName: "Bluetooth", desktopEntry: "org.ambrosia.settings", summary: "Pairing request", body: "Ada's Headphones wants to pair with this computer.",
            expireTimeout: 0, actions: [{ identifier: "accept", text: "Pair", invoke: () => {} }, { identifier: "reject", text: "Cancel", invoke: () => {} }] });
    }
}
