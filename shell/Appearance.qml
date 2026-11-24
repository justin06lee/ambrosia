pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import Ambrosia

// Light or dark, the accent color and Night Light, for the shell and for
// apps: the shell follows Settings; apps get the matching Ambrosia color
// scheme and accent through Plasma, whichever of Control Center and the
// Settings app changed them. GTK 4 apps hear of light or dark from the
// portal, which answers from that scheme; GTK 3 apps are told by
// gtk-appearance (session/), for the ones opened from then on. In Auto,
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

    // Made when something first names it, which may be after the settings are in.
    Component.onCompleted: {
        if (Settings.loaded)
            tellGtk();
    }
    // Once things have settled: at the start the settings arrive in pieces,
    // and two of these at once would each rewrite the same two files.
    function tellGtk() {
        gtk.restart();
    }
    Timer {
        id: gtk
        interval: 500
        onTriggered: Quickshell.execDetached(["/usr/lib/ambrosia/gtk-appearance", Settings.dark ? "dark" : "light"])
    }

    Connections {
        target: Settings
        // What GTK 3 reads may be from before this session, or another's.
        function onLoadedChanged() {
            if (Settings.loaded)
                appearance.tellGtk();
        }
        // A scheme brings its own accent, so the chosen one goes on after it.
        function onDarkChanged() {
            if (!Settings.loaded)
                return;
            appearance.tellGtk();
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
