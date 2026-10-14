pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// The first display's brightness, through Plasma's power manager
// (org.kde.ScreenBrightness): built-in panels, and external monitors that
// speak DDC/CI. `available` is false when there is no display it can dim.
Singleton {
    id: brightness

    property string display: ""
    property int max: 0
    property real value: 0
    readonly property bool available: display !== "" && max > 0

    readonly property string service: "org.kde.ScreenBrightness"

    function refresh() {
        displays.running = true;
    }
    function set(fraction) {
        if (!available) return;
        value = Math.max(0, Math.min(1, fraction));
        Quickshell.execDetached(["busctl", "--user", "call", service, `/org/kde/ScreenBrightness/${display}`,
            "org.kde.ScreenBrightness.Display", "SetBrightness", "iu", String(Math.round(value * max)), "0"]);
    }

    Component.onCompleted: refresh()

    // `as 1 "display0"`: the displays it can dim.
    Process {
        id: displays
        command: ["busctl", "--user", "get-property", brightness.service, "/org/kde/ScreenBrightness",
            "org.kde.ScreenBrightness", "DisplaysDBusNames"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.match(/"([^"]+)"/);
                brightness.display = names ? names[1] : "";
                if (brightness.display) level.running = true;
            }
        }
    }

    // `i 3000` then `i 10000`: the brightness and its maximum.
    Process {
        id: level
        command: ["busctl", "--user", "get-property", brightness.service, `/org/kde/ScreenBrightness/${brightness.display}`,
            "org.kde.ScreenBrightness.Display", "Brightness", "MaxBrightness"]
        stdout: StdioCollector {
            onStreamFinished: {
                const numbers = text.split("\n").map(line => parseInt(line.split(" ")[1])).filter(n => !isNaN(n));
                if (numbers.length < 2 || numbers[1] <= 0) return;
                brightness.max = numbers[1];
                brightness.value = numbers[0] / numbers[1];
            }
        }
    }
}
