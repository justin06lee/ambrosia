import QtQuick
import Quickshell
import Quickshell.DBusMenu
import Quickshell.Services.SystemTray
import "../parts"
import "../../../out/build/qmlshot/shell"

// Apps' own status items in the menu bar, left of ours: a one-color glyph
// (white, with a dot of color: it must come out in the bar's text color),
// an app's colored mark, one that is passive and so stays out, and the first
// one's menu open.
Desk {
    readonly property string icons: Qt.resolvedUrl("../../../dist/icons/Ambrosia/")
    // The first one's menu, as its app would publish it.
    DBusMenuSource { id: syncMenu; service: "sync" }
    then: () => {
        Quickshell.shotMenus = Object.assign({}, Quickshell.shotMenus, { sync: [{ text: "Up to date", enabled: false }, "-",
            "Sync Now", "Pause Syncing", "-", "Open Folder", "Settings…", "-", "Quit"] });
        SystemTray.shotItems = [
            { id: "sync", title: "Sync", icon: Qt.resolvedUrl("art/status-sync.svg"), status: Status.Active, hasMenu: true, menu: syncMenu },
            { id: "store", title: "Updates", icon: icons + "apps/scalable/plasmadiscover.svg", status: Status.NeedsAttention, hasMenu: false },
            { id: "quiet", title: "Quiet", icon: icons + "apps/scalable/ark.svg", status: Status.Passive, hasMenu: false },
        ];
        open.start();
    }
    Timer {
        id: open
        interval: 200
        onTriggered: {
            const at = extra(0).mapToItem(null, 10, 10);
            shotPointer.click(at.x, at.y);
        }
    }
    // The nth status item, found by its owner's name.
    function extra(n) {
        const found = [];
        const walk = item => {
            if (item.owner !== undefined && String(item.owner).startsWith("extra:")) found.push(item);
            for (const child of item.children) walk(child);
        };
        walk(bar.contentItem);
        return found[n];
    }
}
