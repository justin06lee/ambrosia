import QtQuick
import Preview
import "view.mjs" as View

// Preview itself: no window of its own, one for each document. The
// pictures of one launch open together in a window (or each in its own:
// Preview's Settings), each PDF in its own;
// a file already open comes to the front instead. Started with nothing to
// open, it asks with the Open panel, as a Mac's does, and leaves if that
// is cancelled. The windows open when the session ended are open again
// when it is next started, as a Mac's are after logging back in.
QtObject {
    id: main

    property var windows: []
    property Component maker: Component { PreviewWindow {} }

    function open(files) {
        for (const group of View.groups(files, file => App.isPdf(file), Prefs.separate)) {
            const have = windows.find(w => w.files.length === group.length && w.files.every((file, i) => file === group[i]));
            if (have) {
                App.activate(have);
                continue;
            }
            // A PDF's window opens where that PDF's last did, as large; a
            // picture's is fitted to the picture each time, where KWin puts it.
            const made = maker.createObject(null, { files: group, frameName: App.isPdf(group[0]) ? App.frameFor(group[0]) : "" });
            if (!made) {
                console.warn("Preview: no window for", group, maker.errorString());
                continue;
            }
            windows = windows.concat([made]);
            made.closing.connect(() => main.closed(made));
        }
    }
    function closed(which) {
        // Closed by the session on its way out: open again at the next
        // login.
        if (App.leaving())
            App.keep(which.files);
        windows = windows.filter(w => w !== which);
        which.destroy(200);
    }

    property Connections app: Connections {
        target: App
        function onOpenRequested(files) {
            main.open(files);
        }
        function onChooseCancelled() {
            if (main.windows.length === 0)
                Qt.quit();
        }
    }

    // What it was started for, then the windows the last session ended
    // with, each as it was; the Open panel if there is neither.
    Component.onCompleted: {
        if (App.files.length > 0)
            open(App.files);
        for (const kept of App.takeKept())
            open(kept);
        if (windows.length === 0)
            App.chooseFiles();
    }
}
