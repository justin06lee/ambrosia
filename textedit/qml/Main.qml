import QtQuick
import TextEditor

// TextEdit itself: no window of its own, one for each document. Started
// with nothing to open it makes a new one, Untitled; a document already
// open comes to the front instead of opening twice; a new window nothing
// was typed into gives way to the first document opened.
// The documents open when the session ended are open again when it is
// next started, as a Mac's are after logging back in.
QtObject {
    id: main

    property var windows: []
    property int untitled: 0
    property Component maker: Component { EditorWindow {} }

    function make(properties) {
        const made = maker.createObject(null, Object.assign({ app: main }, properties));
        if (!made) {
            console.warn("TextEdit: no window:", maker.errorString());
            return null;
        }
        windows = windows.concat([made]);
        return made;
    }
    function newDocument() {
        untitled += 1;
        make({ rich: !App.plain && Prefs.rich, untitledName: untitled === 1 ? "Untitled" : "Untitled " + untitled });
    }
    function open(files) {
        for (const file of files) {
            const have = windows.find(w => w.file === file);
            if (have) {
                App.activate(have);
                continue;
            }
            const spare = windows.filter(w => w.pristine);
            if (make({ opening: file, frameName: App.frameFor(file) }))
                spare.forEach(w => w.close());
        }
    }
    function closed(which) {
        // Closed by the session on its way out: open again at the next
        // login (a document never saved has no file to open then).
        if (which.file !== "" && App.leaving())
            App.keep([which.file]);
        windows = windows.filter(w => w !== which);
        which.destroy(200);
    }
    // Quit: each document with changes asks first, one after another;
    // Cancel in any of them calls it off.
    function quit() {
        const edited = windows.find(w => w.edited);
        if (!edited) {
            Qt.quit();
            return;
        }
        App.activate(edited);
        edited.askClose(() => main.quit());
    }

    property Connections app: Connections {
        target: App
        function onOpenRequested(files) {
            main.open(files);
        }
        function onRaiseRequested() {
            if (main.windows.length > 0)
                App.activate(main.windows[main.windows.length - 1]);
            else
                main.newDocument();
        }
    }

    // What it was started for, then the documents the last session ended
    // with; a new one if there is neither.
    Component.onCompleted: {
        const files = App.files.slice();
        for (const kept of App.takeKept()) {
            if (!files.includes(kept[0]))
                files.push(kept[0]);
        }
        if (files.length > 0)
            open(files);
        else
            newDocument();
    }
}
