import Quickshell
import Quickshell.Io
import QtQuick
import org.kde.taskmanager as TaskManager

// The Mac-first keyboard's per-app half (design/DECISIONS.md, docs/keyboard.md).
// keyd turns ⌘ into the Ctrl every app documents; a terminal wants Ctrl+Shift
// for the same shortcuts, and Files keeps ⌘ with the arrows for itself. This
// tells the system which kind of app has the keyboard: one word down
// /run/ambrosia-keys, where ambrosia-keys.service applies the keyd bindings
// filed under it (/usr/share/ambrosia/keys, /etc/ambrosia/keys). With keyd
// off (the Linux-first keyboard) there is no pipe and nothing happens.
Scope {
    id: layer

    // An app is a terminal when its desktop file says so. The apps named in
    // ~/.config/ambrosia/keys.json get the layer named there instead:
    // { "org.wezfurlong.wezterm": "terminal", "org.kde.kate": "default" }.
    readonly property var builtin: ({ "org.ambrosia.files": "files" })
    property var named: ({})
    FileView {
        path: Quickshell.env("HOME") + "/.config/ambrosia/keys.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                layer.named = JSON.parse(text()) ?? {};
            } catch (error) {
                layer.named = {};
            }
        }
        onLoadFailed: layer.named = ({})
    }

    // The app with the keyboard, read from the task model itself: Apps holds
    // its own answer still while a menu is open. Read again whenever the
    // model changes, as Apps does, not only when its active task does.
    property string appId: ""
    function read() {
        const index = Apps.tasks.activeTask;
        appId = index.valid ? (Apps.get(index, TaskManager.AbstractTasksModel.AppId) ?? "").replace(/\.desktop$/, "") : "";
    }
    Connections {
        target: Apps.tasks
        function onActiveTaskChanged() { layer.read(); }
        function onDataChanged() { layer.read(); }
        function onRowsInserted() { layer.read(); }
        function onRowsRemoved() { layer.read(); }
        function onModelReset() { layer.read(); }
        function onLayoutChanged() { layer.read(); }
    }

    readonly property string profile: {
        if (!appId) return "default";
        const name = named[appId] ?? builtin[appId];
        if (typeof name === "string" && /^[a-z0-9_-]{1,32}$/.test(name)) return name;
        const categories = Array.from(Apps.entryFor(appId, "")?.categories ?? []);
        return categories.includes("TerminalEmulator") ? "terminal" : "default";
    }
    onProfileChanged: send()
    // Also at the start, whatever it is: the shell before this one may have
    // left a terminal's layer on.
    Component.onCompleted: {
        read();
        send();
    }

    // One writer at a time, so the words arrive in order; a change made
    // meanwhile goes out when this one is through.
    property string sent: ""
    function send() {
        if (pipe.running) return;
        sent = profile;
        pipe.command = ["sh", "-c", "[ -p /run/ambrosia-keys ] && printf '%s\\n' \"$1\" >/run/ambrosia-keys", "sh", profile];
        pipe.running = true;
    }
    Process {
        id: pipe
        onExited: if (layer.sent !== layer.profile) layer.send()
    }
}
