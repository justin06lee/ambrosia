import QtQuick
import Preview
import "view.mjs" as View

// Preview itself: no window of its own, one for each document. The
// pictures of one launch open together in a window (or each in its own:
// Preview's Settings), each PDF in its own;
// a file already open comes to the front instead. Started with nothing to
// open, it asks with the Open panel, as a Mac's does, and leaves if that
// is cancelled.
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
            const made = maker.createObject(null, { files: group });
            if (!made) {
                console.warn("Preview: no window for", group, maker.errorString());
                continue;
            }
            windows = windows.concat([made]);
            made.closing.connect(() => main.closed(made));
        }
    }
    function closed(which) {
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

    Component.onCompleted: App.files.length > 0 ? open(App.files) : App.chooseFiles()
}
