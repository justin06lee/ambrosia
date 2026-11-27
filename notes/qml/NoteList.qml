import QtQuick
import QtQuick.Controls.Basic as Controls
import Qt.labs.platform as Platform
import Ambrosia
import Notes
import "notes.mjs" as Logic

// The list of notes, 280 wide: under each heading (Pinned, Today, … from
// notes.mjs sections()) a row for each note, its name over its date and the
// line after its name. The heading at the top stays there, on the bar's
// color, while its notes pass under it. The chosen note stands on a rounded
// fill: Notes' yellow while the list has the keys, gray otherwise.
Item {
    id: list

    required property var window
    readonly property bool front: window.looksActive
    readonly property bool keyed: view.activeFocus
    // Headings and rows in one run, each knowing how far down it stands.
    readonly property var flat: {
        const made = [];
        let y = Look.listTop;
        const parts = window.parts;
        for (let at = 0; at < parts.length; ++at) {
            const part = parts[at];
            if (part.title !== "") {
                if (at > 0)
                    y += Look.listSectionGap;
                made.push({ heading: true, title: part.title, key: part.key, top: y, tall: Look.listHeading, gap: at > 0 ? Look.listSectionGap : 0, shut: part.key === "pinned" && window.pinnedShut });
                y += Look.listHeading;
                if (part.key === "pinned" && window.pinnedShut)
                    continue;
            }
            for (let k = 0; k < part.rows.length; ++k) {
                made.push({ heading: false, row: part.rows[k], key: part.rows[k].key, top: y, tall: Look.listRow, gap: 0, last: k === part.rows.length - 1 });
                y += Look.listRow;
            }
        }
        return made;
    }
    readonly property real tall: flat.length > 0 ? flat[flat.length - 1].top + flat[flat.length - 1].tall + 12 : 0
    // Only what is in sight is drawn, and a few rows either side: the
    // stretch moves eight rows at a time.
    readonly property var seen: {
        const top = view.contentY - 12 * Look.listRow, bottom = view.contentY + view.height + 12 * Look.listRow;
        let first = 0, last = flat.length;
        for (let at = 0; at < flat.length; ++at) {
            if (flat[at].top + flat[at].tall < top)
                first = at + 1;
            if (flat[at].top > bottom) {
                last = at;
                break;
            }
        }
        // (In steps of eight, so that a scroll doesn't build the rows anew
        // at every one of them.)
        first = Math.floor(first / 8) * 8;
        last = Math.min(flat.length, Math.ceil(last / 8) * 8);
        return first + ":" + last;
    }
    readonly property var drawn: {
        const ends = seen.split(":");
        return flat.slice(Number(ends[0]), Number(ends[1]));
    }
    readonly property bool headed: flat.some(item => item.heading)
    // The heading held at the top: the last one the list has reached.
    readonly property var held: {
        let found = null;
        for (const item of flat) {
            if (!item.heading)
                continue;
            if (found === null || item.top <= view.contentY + Look.listTop)
                found = item;
            else
                break;
        }
        return found;
    }

    function take() {
        view.forceActiveFocus();
    }
    onFlatChanged: Qt.callLater(list.reveal)
    function reveal() {
        const item = flat.find(entry => entry.key === window.chosen);
        // (Not before the list has its height: everything is out of sight
        // of a list none tall.)
        if (!item || view.height <= 0)
            return;
        const over = list.headed ? Look.listHeading : 0;
        const most = Math.max(0, list.tall - view.height);
        if (item.top - over < view.contentY)
            view.contentY = Math.max(0, Math.min(most, item.top - over - Look.listTop));
        else if (item.top + item.tall > view.contentY + view.height)
            view.contentY = Math.min(most, item.top + item.tall - view.height + 6);
        else if (view.contentY > most)
            view.contentY = most;
    }
    Connections {
        target: list.window
        function onChosenChanged() {
            Qt.callLater(list.reveal);
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Look.listFill
    }

    Flickable {
        id: view
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: list.tall
        onHeightChanged: Qt.callLater(list.reveal)
        Controls.ScrollBar.vertical: ScrollThumb {}
        Accessible.role: Accessible.List
        Accessible.name: "Notes"
        activeFocusOnTab: true

        Keys.onPressed: (event) => {
            if (event.modifiers & (Qt.AltModifier | Qt.MetaModifier))
                return;
            const command = event.modifiers & Qt.ControlModifier;
            switch (event.key) {
            case Qt.Key_Up: list.window.step(-1); break;
            case Qt.Key_Down: list.window.step(1); break;
            case Qt.Key_Home: list.window.step(-100000); break;
            case Qt.Key_End: list.window.step(100000); break;
            case Qt.Key_Left: list.window.focusSidebar(); break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Tab:
            case Qt.Key_Right:
                if (command)
                    return;
                list.window.focusNote();
                break;
            case Qt.Key_Backspace:
            case Qt.Key_Delete:
                list.window.deleteNote(list.window.chosen);
                break;
            default:
                return;
            }
            event.accepted = true;
        }

        // A click on nothing: the keys are the list's.
        MouseArea {
            width: view.width
            height: Math.max(view.height, list.tall)
            onPressed: list.take()
        }

        Repeater {
            model: list.drawn

            Item {
            id: cell
            required property var modelData
            readonly property bool chosen: !modelData.heading && modelData.key === list.window.chosen

            y: modelData.top
            width: view.width
            height: modelData.tall

            // A heading (the held one is drawn over the list instead).
            Item {
                visible: cell.modelData.heading
                width: parent.width
                height: Look.listHeading
                Label {
                    x: Look.listHeadingX
                    y: Look.listHeadingBase - baselineOffset
                    text: cell.modelData.heading ? cell.modelData.title : ""
                    font.pixelSize: 15
                    font.weight: 700
                    color: Look.text
                }
            }

            // A note.
            Item {
                visible: !cell.modelData.heading
                anchors.fill: parent
                Accessible.role: Accessible.ListItem
                Accessible.name: cell.modelData.heading ? "" : cell.modelData.row.title

                Rectangle {
                    visible: cell.chosen
                    x: Look.listInset
                    width: parent.width - 2 * Look.listInset
                    height: parent.height
                    radius: 8
                    color: !list.front ? Look.chosenNoteInactive : list.keyed ? Look.chosenNote : Look.chosenNoteQuiet
                }
                Label {
                    x: Look.listTextX
                    y: Look.listNameBase - baselineOffset
                    width: parent.width - x - Look.listInset - 12
                    elide: Text.ElideRight
                    text: cell.modelData.heading ? "" : cell.modelData.row.title
                    font.pixelSize: 13
                    font.weight: 700
                    color: Look.text
                }
                Label {
                    id: date
                    x: Look.listTextX
                    y: Look.listLineBase - baselineOffset
                    text: cell.modelData.heading ? "" : Logic.rowDate(list.window.dateOf(cell.modelData.row), list.window.now, App.hour24)
                    style: Theme.text.callout
                    color: Look.text
                }
                Label {
                    x: date.x + date.width + 8
                    y: Look.listLineBase - baselineOffset
                    width: parent.width - x - Look.listInset - 12
                    elide: Text.ElideRight
                    text: cell.modelData.heading ? "" : cell.modelData.row.snippet
                    style: Theme.text.callout
                    color: cell.chosen && list.front && list.keyed && Look.dark ? Look.text : Look.note
                }
                // The rule under a row: not under the chosen one, nor the
                // one over it, nor a section's last.
                Rectangle {
                    visible: !cell.modelData.heading && !cell.modelData.last && !cell.chosen && cell.modelData.key !== list.window.before
                    x: Look.listTextX
                    y: parent.height - 0.5
                    width: parent.width - x - Look.listRuleEnd
                    height: 0.5
                    color: Look.rule
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onPressed: (mouse) => {
                        list.window.choose(cell.modelData.key);
                        list.take();
                        if (mouse.button === Qt.RightButton) {
                            noteMenu.about = cell.modelData.key;
                            noteMenu.open();
                        }
                    }
                    onDoubleClicked: list.window.focusNote()
                }
            }
            }
        }
    }

    // The heading held at the top.
    Rectangle {
        visible: list.headed && list.held !== null
        width: parent.width
        height: Look.listHeading
        color: Look.listBar
        Label {
            x: Look.listHeadingX
            y: Look.listHeadingBase - baselineOffset
            text: list.held?.title ?? ""
            font.pixelSize: 15
            font.weight: 700
            color: Look.text
        }
        // Pinned notes can be shut away.
        Glyph {
            visible: list.held?.key === "pinned"
            x: parent.width - 37
            y: (parent.height - height) / 2
            name: list.window.pinnedShut ? "chevronRight" : "chevronDown"
            size: 13.5
            color: Look.chevron
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (list.held?.key === "pinned")
                    list.window.pinnedShut = !list.window.pinnedShut;
                list.take();
            }
        }
        Rectangle {
            y: parent.height - 0.5
            width: parent.width
            height: 0.5
            color: Look.hairline
        }
    }

    // Nothing to list.
    Label {
        visible: list.flat.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.4)
        text: list.window.query.trim() !== "" ? "No Results" : "No Notes"
        style: Theme.text.title3
        font.weight: 700
        color: Look.faint
    }

    Platform.Menu {
        // (Not `menu`: inside an item of its submenu that is the item's own
        // property, the menu it is in.)
        id: noteMenu
        property string about: ""
        readonly property var row: list.window.rowOf(about)
        readonly property bool gone: row?.folder === Logic.deleted
        Platform.MenuItem { visible: !noteMenu.gone; text: noteMenu.row?.pinned ? "Unpin Note" : "Pin Note"; onTriggered: list.window.togglePin(noteMenu.about) }
        Platform.MenuItem { visible: noteMenu.gone; text: "Recover"; onTriggered: list.window.recover(noteMenu.about) }
        Platform.Menu {
            id: moveMenu
            title: "Move to"
            visible: !noteMenu.gone
            Instantiator {
                model: list.window.side.filter(folder => folder.key !== Logic.everything && folder.key !== Logic.deleted)
                delegate: Platform.MenuItem {
                    required property var modelData
                    text: modelData.name
                    enabled: !noteMenu.row || modelData.key !== noteMenu.row.folder
                    onTriggered: list.window.moveNote(noteMenu.about, modelData.key)
                }
                onObjectAdded: (index, object) => moveMenu.insertItem(index, object)
                onObjectRemoved: (index, object) => moveMenu.removeItem(object)
            }
        }
        Platform.MenuSeparator {}
        Platform.MenuItem { text: noteMenu.gone ? "Delete Permanently…" : "Delete"; onTriggered: list.window.deleteNote(noteMenu.about) }
    }
}
