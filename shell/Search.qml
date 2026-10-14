import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import Ambrosia

// Search (Super+Space, or the magnifier in the menu bar): type to find an
// app, arrows to choose, Return to open it, Escape or a click outside to
// close. It covers the screen while open so the click outside lands here.
PanelWindow {
    id: search

    // The screen this window was made for (its live `screen` changes as it
    // maps and unmaps, which would loop through `visible`).
    required property ShellScreen home
    readonly property bool open: Popups.searchOpen && Popups.searchScreen === home
    property string query: ""
    property int current: 0
    readonly property int rowHeight: Theme.size.row.large
    readonly property int maxRows: 8

    // Apps whose name, generic name or keywords match, best first: names
    // that start with the query, then words that do, then names containing it.
    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (q === "") return [];
        const scored = [];
        for (const entry of DesktopEntries.applications.values) {
            if (entry.noDisplay) continue;
            const name = entry.name.toLowerCase();
            const words = [name, entry.genericName.toLowerCase()].concat(entry.keywords.map(k => k.toLowerCase()));
            let score = 0;
            if (name.startsWith(q)) score = 3;
            else if (words.some(w => w.split(/[\s-]+/).some(part => part.startsWith(q)))) score = 2;
            else if (words.some(w => w.includes(q))) score = 1;
            if (score > 0) scored.push({ entry, score });
        }
        scored.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
        return scored.slice(0, maxRows).map(s => s.entry);
    }

    function launch(entry) {
        if (!entry) return;
        Popups.searchOpen = false;
        Session.launch(entry.id);
    }

    visible: open
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ambrosia-search"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    BackgroundEffect.blurRegion: Region { item: panel; radius: Theme.radius.panel }

    onOpenChanged: {
        query = "";
        field.text = "";
        current = 0;
        if (open) field.forceActiveFocus();
    }
    onResultsChanged: current = 0

    MouseArea {
        anchors.fill: parent
        onPressed: Popups.searchOpen = false
    }

    Item {
        id: panel
        x: (parent.width - width) / 2
        y: parent.height * 0.22
        width: 640
        height: fieldRow.height + (search.results.length > 0 ? list.height + 1 + 2 * Theme.space.s1_5 : 0)

        Glass {
            anchors.fill: parent
            tint: Theme.color.material.thick.tint
            radius: Theme.radius.panel
            shadow: Theme.color.shadow.window
        }

        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: fieldRow
            width: parent.width
            height: 52

            Icon {
                id: magnifier
                x: Theme.space.s4
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 22
                color: Theme.color.label.secondary
            }

            TextInput {
                id: field
                anchors { left: magnifier.right; right: parent.right; leftMargin: Theme.space.s3; rightMargin: Theme.space.s4; verticalCenter: parent.verticalCenter }
                font.family: Theme.uiFont
                font.pixelSize: Theme.text.title2.size + 3
                font.weight: Font.Normal
                color: Theme.color.label.primary
                selectionColor: Theme.accent.highlight
                clip: true
                focus: search.open
                onTextChanged: search.query = text

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        Popups.searchOpen = false;
                        break;
                    case Qt.Key_Down:
                        search.current = Math.min(search.current + 1, search.results.length - 1);
                        break;
                    case Qt.Key_Up:
                        search.current = Math.max(search.current - 1, 0);
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        search.launch(search.results[search.current]);
                        break;
                    default:
                        return;
                    }
                    event.accepted = true;
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: field.text === ""
                    text: "Search"
                    font.pixelSize: field.font.pixelSize
                    font.weight: Font.Normal
                    color: Theme.color.label.tertiary
                }
            }
        }

        Rectangle {
            visible: search.results.length > 0
            anchors.top: fieldRow.bottom
            width: parent.width
            height: 1
            color: Theme.color.separator
        }

        Column {
            id: list
            anchors { top: fieldRow.bottom; topMargin: 1 + Theme.space.s1_5; left: parent.left; right: parent.right; leftMargin: Theme.space.s1_5; rightMargin: Theme.space.s1_5 }

            Repeater {
                model: search.results

                Item {
                    id: result
                    required property var modelData
                    required property int index
                    readonly property bool highlighted: search.current === index
                    width: list.width
                    height: search.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius.control
                        color: Theme.accent.bg
                        visible: result.highlighted
                    }

                    IconImage {
                        id: appIcon
                        x: Theme.space.s2
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 32
                        source: Quickshell.iconPath(result.modelData.icon, "application-x-executable")
                    }

                    Column {
                        anchors { left: appIcon.right; right: parent.right; leftMargin: Theme.space.s3; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }

                        Label {
                            width: parent.width
                            text: result.modelData.name
                            style: Theme.text.body
                            color: result.highlighted ? Theme.accent.fg : Theme.color.label.primary
                            elide: Text.ElideRight
                        }
                        Label {
                            width: parent.width
                            visible: text !== ""
                            text: result.modelData.genericName || result.modelData.comment
                            style: Theme.text.caption
                            color: result.highlighted ? Theme.accent.fg : Theme.color.label.secondary
                            opacity: result.highlighted ? 0.8 : 1
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: search.current = result.index
                        onClicked: search.launch(result.modelData)
                    }
                }
            }
        }
    }
}
