pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Things the shell asks the system to do. Apps and commands start through
// kstart, so each lands in its own systemd scope rather than in the shell's
// service, and outlives a restart of the shell.
Singleton {
    id: session

    // The person logged in, for "Log Out <name>…".
    property string userName: Quickshell.env("USER") ?? ""

    function launch(desktopId) {
        Quickshell.execDetached(["kstart", "--application", desktopId]);
    }
    function run(command) {
        Quickshell.execDetached(["kstart", "--"].concat(command));
    }
    // Opens a file, folder or URL in the app that handles it.
    function open(url) {
        Quickshell.execDetached(["kioclient", "exec", url]);
    }
    // System Settings (ambrosia-settings), on one of its panes: general,
    // about, wifi, network, bluetooth, sound, battery, datetime…
    function settings(pane) {
        run(pane ? ["ambrosia-settings", "--pane", pane] : ["ambrosia-settings"]);
    }

    function lock() {
        Quickshell.execDetached(["loginctl", "lock-session"]);
    }
    function sleep() {
        Quickshell.execDetached(["systemctl", "suspend"]);
    }
    // Plasma's session manager closes apps (letting them save) before it
    // logs out, restarts or shuts down.
    function logOut() {
        shutdownCall("logout");
    }
    function restart() {
        shutdownCall("logoutAndReboot");
    }
    function shutDown() {
        shutdownCall("logoutAndShutdown");
    }
    // KWin's kill-window mode: the next window clicked is force-quit.
    function forceQuit() {
        Quickshell.execDetached(["dbus-send", "--session", "--type=method_call", "--dest=org.kde.KWin", "/KWin", "org.kde.KWin.killWindow"]);
    }
    function screenshot() {
        Quickshell.execDetached(["spectacle", "--region"]);
    }

    function shutdownCall(method) {
        Quickshell.execDetached(["dbus-send", "--session", "--type=method_call", "--dest=org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown." + method]);
    }

    Process {
        running: true
        command: ["getent", "passwd", Quickshell.env("USER") ?? ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const gecos = (text.split(":")[4] ?? "").split(",")[0].trim();
                if (gecos) session.userName = gecos;
            }
        }
    }
}
