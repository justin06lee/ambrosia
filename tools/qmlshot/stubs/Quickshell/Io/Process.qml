import QtQml
import Quickshell

// A command that is never started. If the sheet's Quickshell.shotRun
// answers for it (a function given the command, returning what it would
// have printed, or a number: the code it ended with, having printed
// nothing), that reaches stdout and it ends; otherwise it stays as a
// command that hasn't finished.
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
        const answer = typeof Quickshell.shotRun === "function" ? Quickshell.shotRun(command) : undefined;
        // What it printed, or a number: it printed nothing and ended with that code.
        if (typeof answer !== "string" && typeof answer !== "number") return;
        const printed = typeof answer === "string" ? answer : "";
        started();
        if (stdout && "text" in stdout) {
            stdout.text = printed;
            stdout.streamFinished();
        } else if (stdout) {
            for (const line of printed.split("\n")) stdout.read(line);
        }
        running = false;
        exited(typeof answer === "number" ? answer : 0, 0);
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
