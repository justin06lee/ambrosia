pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import Ambrosia

// Light or dark, the accent color and Night Light, for the shell and for
// apps: the shell follows Settings; apps get the matching Ambrosia color
// scheme and accent through Plasma, which passes them on to GTK apps too.
Singleton {
    id: appearance

    property bool nightLight: false

    function setDark(dark) {
        Settings.dark = dark;
        Quickshell.execDetached(["plasma-apply-colorscheme", dark ? "AmbrosiaDark" : "AmbrosiaLight"]);
    }
    function setAccent(name) {
        Settings.accent = name;
        Quickshell.execDetached(["plasma-apply-colorscheme", "--accent-color", Theme.color.accents[name].bg.toString()]);
    }
    // On, it stays warm until turned off (KWin's constant mode).
    function setNightLight(on) {
        nightLight = on;
        Quickshell.execDetached(["sh", "-c",
            `kwriteconfig6 --file kwinrc --group NightColor --key Active ${on} && ` +
            "kwriteconfig6 --file kwinrc --group NightColor --key Mode Constant && " +
            "dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.reconfigure"]);
    }

    Process {
        running: true
        command: ["kreadconfig6", "--file", "kwinrc", "--group", "NightColor", "--key", "Active"]
        stdout: StdioCollector {
            onStreamFinished: appearance.nightLight = text.trim() === "true"
        }
    }
}
