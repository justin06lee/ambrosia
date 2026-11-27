import QtQuick
import Notes

// Notes itself: its one window. It goes when its window does (a Mac's
// stays in the Dock without one); a note is written as it is typed, so
// nothing is lost by it.
QtObject {
    id: main

    property NotesWindow window: NotesWindow {
        onClosing: Qt.callLater(Qt.quit)
    }

    property Connections app: Connections {
        target: App
        function onShowRequested() {
            main.window.visible = true;
            App.activate(main.window);
        }
    }

    Component.onCompleted: main.window.visible = true
}
