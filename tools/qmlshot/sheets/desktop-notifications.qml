import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// Notification Center open, with a few things heard.
Desk {
    then: () => {
        const server = NotificationStore.server;
        server.shotNotify({ appName: "Discover", desktopEntry: "org.kde.discover", summary: "Updates Available", body: "12 packages can be updated." });
        server.shotNotify({ appName: "Files", desktopEntry: "org.ambrosia.files", summary: "Copy finished", body: "ambrosia-2026.11.10-x86_64.iso was copied to Backups." });
        server.shotNotify({ appName: "Files", desktopEntry: "org.ambrosia.files", summary: "Trash emptied", body: "34 items were erased." });
        server.shotNotify({ appName: "Spectacle", desktopEntry: "org.kde.spectacle", summary: "Screenshot saved", body: "Screenshot 2026-11-18 at 09.41.12.png is in Pictures." });
        Popups.toggleNotificationCenter(screen);
    }
}
