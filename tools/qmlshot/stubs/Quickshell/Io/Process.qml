import QtQml
import Quickshell

// A command that is never started. If the sheet's Quickshell.shotRun
// answers for it (a function given the command, returning what it would
// have printed), that reaches stdout and it ends well; otherwise it stays
// as a command that hasn't finished.
QtObject {
    id: process

    property bool running: false
    property var command: []
    property QtObject stdout: null
    property QtObject stderr: null
    property bool stdinEnabled: false
    property var environment: ({})
    property string workingDirectory
    signal started()
    signal exited(int exitCode, int exitStatus)

    function write(data) {}

    property bool shotQueued: false
    function shotStart() {
        shotQueued = false;
        if (!running) return;
        const printed = typeof Quickshell.shotRun === "function" ? Quickshell.shotRun(command) : undefined;
        if (typeof printed !== "string") return;
        if (stdout && "text" in stdout) {
            stdout.text = printed;
            stdout.streamFinished();
        } else if (stdout) {
            for (const line of printed.split("\n")) stdout.read(line);
        }
        running = false;
        exited(0, 0);
    }
    // After the sheet has had its say (its Component.onCompleted).
    function shotQueue() {
        if (!running || shotQueued) return;
        shotQueued = true;
        Qt.callLater(shotStart);
    }
    onRunningChanged: shotQueue()
    Component.onCompleted: shotQueue()
}
