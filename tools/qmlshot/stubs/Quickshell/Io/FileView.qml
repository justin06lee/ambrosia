import QtQml
import Quickshell

// A file that is never opened. It holds what the sheet put under its name
// in Quickshell.shotFiles (nothing, otherwise), says it loaded once the
// sheet has had its say, and writes nowhere.
QtObject {
    id: view

    default property QtObject adapter
    property string path
    property bool watchChanges: false
    property bool blockAllReads: false
    property bool blockLoading: false
    property bool blockWrites: false
    property bool printErrors: true
    property bool preload: true
    property bool atomicWrites: true
    signal loaded()
    signal fileChanged()
    signal adapterUpdated()
    signal loadFailed(int error)
    signal saved()
    signal saveFailed(int error)

    function text() {
        return Quickshell.shotFiles[path.split("/").pop()] ?? "";
    }
    function reload() {}
    function writeAdapter() {}
    function setText(text) {}
    function waitForJob() {}

    Component.onCompleted: Qt.callLater(() => view.loaded())
}
