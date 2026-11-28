import QtQuick
import Ambrosia
import Files

// The status bar along the window's bottom (View ▸ Show Status Bar): how
// many items the folder has, or how many of them are selected, and the room
// left on its disk, as Finder's says it. Not measured from Finder's (it
// shows none on the Mac at hand): the path bar's rule and words, a little
// lower.
Item {
    id: bar

    required property var finder

    height: Finder.statusBar

    // Read again when the folder or what is in it changes.
    readonly property string room: {
        finder.model.count;
        return App.roomOn(finder.url);
    }
    readonly property string words: {
        const count = finder.model.count;
        const items = count === 1 ? "1 item" : count.toLocaleString(Qt.locale(), "f", 0) + " items";
        const chosen = finder.selectedCount;
        const what = chosen > 0 ? chosen.toLocaleString(Qt.locale(), "f", 0) + " of " + count.toLocaleString(Qt.locale(), "f", 0) + " selected" : items;
        return room !== "" && !finder.searching ? what + ", " + room + " available" : what;
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Finder.separator
    }

    Label {
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - 26)
        elide: Text.ElideMiddle
        text: bar.words
        style: Theme.text.callout
        color: Theme.color.label.secondary
    }
}
