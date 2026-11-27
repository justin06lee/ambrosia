import QtQuick
import FontBook

// Font Book itself: its one window, and a preview for each font file
// asked about that isn't on the computer yet (one that is opens its page
// in the window instead). It goes when its last window does.
QtObject {
    id: main

    property FontBookWindow window: FontBookWindow {
        onClosing: Qt.callLater(main.leaveIfDone)
    }
    property var previews: []
    property Component maker: Component { FontFileWindow {} }

    function open(files) {
        if (files.length === 0) {
            main.window.visible = true;
            App.activate(main.window);
            return;
        }
        for (const file of files) {
            const have = previews.find(w => w.file === file.toString());
            if (have) {
                App.activate(have);
                continue;
            }
            const told = Library.inspect(file);
            if (!told.ok) {
                main.window.visible = true;
                App.activate(main.window);
                main.window.say("“" + told.name + "” isn’t a font Font Book can read.", "");
                continue;
            }
            if (told.installed) {
                // On the computer already: its page.
                main.window.visible = true;
                main.window.show(told.family);
                App.activate(main.window);
                continue;
            }
            const made = maker.createObject(null, { file: file.toString(), told: told });
            if (!made) {
                console.warn("Font Book: no preview for", file, maker.errorString());
                continue;
            }
            previews = previews.concat([made]);
            made.closing.connect(() => main.closed(made));
            made.installed.connect((family) => {
                main.window.visible = true;
                main.window.show(family);
                App.activate(main.window);
            });
        }
    }
    function closed(which) {
        previews = previews.filter(w => w !== which);
        which.destroy(200);
        Qt.callLater(main.leaveIfDone);
    }
    function leaveIfDone() {
        if (!main.window.visible && previews.length === 0)
            Qt.quit();
    }

    property Connections app: Connections {
        target: App
        function onOpenRequested(files) {
            main.open(files);
        }
    }

    Component.onCompleted: {
        // Started on font files alone: only their previews, as a Mac
        // shows them; the window comes when one is installed or asked for.
        if (App.files.length > 0) {
            open(App.files);
            if (previews.length === 0)
                main.window.visible = true;
        } else {
            main.window.visible = true;
        }
    }
}
