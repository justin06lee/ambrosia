pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import Ambrosia

// Light or dark, the accent color and Night Light, for the shell and for
// apps: the shell follows Settings; apps get the matching Ambrosia color
// scheme and accent through Plasma, which passes them on to GTK apps too,
// whichever of Control Center and the Settings app changed them. In Auto,
// light or dark follows KDE's night-time service.
Singleton {
    id: appearance

    property bool nightLight: false

    function setDark(dark) {
        Settings.appearance = dark ? "dark" : "light";
        Settings.dark = dark;
    }
    function setAccent(name) {
        Settings.accent = name;
    }

    Connections {
        target: Settings
        // A scheme brings its own accent, so the chosen one goes on after it.
        function onDarkChanged() {
            if (!Settings.loaded)
                return;
            Quickshell.execDetached(["sh", "-c", `plasma-apply-colorscheme ${Settings.dark ? "AmbrosiaDark" : "AmbrosiaLight"}; ` +
                `plasma-apply-colorscheme --accent-color '${Theme.color.accents[Settings.accent].bg}'`]);
        }
        function onAccentChanged() {
            if (!Settings.loaded)
                return;
            Quickshell.execDetached(["plasma-apply-colorscheme", "--accent-color", Theme.color.accents[Settings.accent].bg.toString()]);
        }
    }

    Timer {
        interval: 60000
        repeat: true
        triggeredOnStart: true
        running: Settings.appearance === "auto"
        onTriggered: nightTime.running = true
    }
    // Each day [noon, morning's start and end, evening's start and end], in
    // ms: dark from the middle of evening to the middle of morning.
    Process {
        id: nightTime
        command: ["busctl", "--user", "--json=short", "call", "org.kde.NightTime", "/org/kde/NightTime/Manager",
            "org.kde.NightTime.Manager", "Subscribe", "a{sv}", "0"]
        stdout: StdioCollector {
            onStreamFinished: {
                let days;
                try {
                    days = JSON.parse(text).data[0].Schedule.data[1].data;
                } catch (error) {
                    return;
                }
                const now = Date.now();
                const day = days.find(d => now < (d[3] + d[4]) / 2);
                if (day && Settings.appearance === "auto")
                    Settings.dark = now < (day[1] + day[2]) / 2;
            }
        }
    }
    // On, it stays warm until turned off (KWin's constant mode).
    function setNightLight(on) {
        nightLight = on;
        Quickshell.execDetached(["sh", "-c",
            "kwriteconfig6 --file kwinrc --group NightColor --key Mode Constant --notify && " +
            `kwriteconfig6 --file kwinrc --group NightColor --key Active ${on} --notify`]);
    }

    Process {
        running: true
        command: ["kreadconfig6", "--file", "kwinrc", "--group", "NightColor", "--key", "Active"]
        stdout: StdioCollector {
            onStreamFinished: appearance.nightLight = text.trim() === "true"
        }
    }
}
