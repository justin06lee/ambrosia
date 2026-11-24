import QtQuick
import Quickshell
import "../../../out/build/qmlshot/shell"

// The desk with the installer's assistant open on it, the live image's
// script answered for: two disks, three Wi-Fi networks, a handful of time
// zones. `offline` is a computer with no internet yet; `steps` is what a
// sheet does next, one a turn (a function each), so each has taken before
// the next.
Desk {
    id: desk

    property bool offline: false
    property var steps: []

    running: []
    active: ""
    shotWait: 1500 + 150 * steps.length
    then: () => {
        Quickshell.shotRun = command => {
            if (command[0] !== "/usr/local/bin/ambrosia-install") return undefined;
            switch (command[1]) {
            case "disks": return "/dev/nvme0n1\t476.9G\tSamsung SSD 980 PRO 500GB\n/dev/sda\t931.5G\tWDC WD10EZEX";
            case "online": return desk.offline ? 1 : "";
            case "wifi": return "Mina’s Wi-Fi\t92\tWPA2\nCafé Nectar\t71\t\nOrchard-5G\t48\tWPA2 WPA3";
            case "join": return 1;
            case "timezone": return "Asia/Seoul";
            case "timezones": return ["Africa/Cairo", "America/Los_Angeles", "America/New_York", "America/Argentina/Buenos_Aires",
                "Asia/Seoul", "Asia/Shanghai", "Asia/Singapore", "Asia/Tokyo", "Australia/Sydney", "Europe/London", "Europe/Paris", "UTC"].join("\n");
            }
            return undefined;
        };
        Popups.installerOpen = true;
        turn.start();
    }
    Timer {
        id: turn
        interval: 150
        repeat: true
        onTriggered: {
            const step = desk.steps.shift();
            if (step) step(); else stop();
        }
    }
}
