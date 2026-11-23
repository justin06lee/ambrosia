import Quickshell
import Quickshell.Widgets
import QtQuick
import org.kde.taskmanager as TaskManager
import Ambrosia

// Force Quit Applications, as ⌥⌘Esc shows on a Mac: the apps with a window
// open, one chosen, and a button that ends it without asking it anything
// (after we ask once). The arrows move, Return is the button, Escape closes.
Item {
    id: panel

    readonly property Region blurArea: Region { item: panel; radius: Theme.radius.panel }
    // The apps with a window, as { row, name, icon }, read when this opens.
    property var running: []
    property int current: 0

    function refresh() {
        const list = [];
        for (let row = 0; row < Apps.tasks.rowCount(); row++) {
            if (Apps.windowsOf(row).length === 0) continue;
            const index = Apps.tasks.makeModelIndex(row);
            const name = Apps.get(index, TaskManager.AbstractTasksModel.AppName) || Apps.get(index, Qt.DisplayRole) || "";
            const entry = Apps.entryFor(Apps.get(index, TaskManager.AbstractTasksModel.AppId), name);
            list.push({ row: row, name: entry?.name || name, icon: entry?.icon ?? "" });
        }
        running = list;
        current = 0;
    }
    function move(step) {
        if (running.length > 0) current = Math.max(0, Math.min(running.length - 1, current + step));
    }
    function accept() {
        const app = running[current];
        if (!app) return;
        Popups.confirm(Popups.screen, {
            title: `Do you want to force “${app.name}” to quit?`,
            text: "You will lose any unsaved changes.",
            accept: "Force Quit",
            action: () => Apps.forceQuit(app.row),
        });
    }

    onVisibleChanged: if (visible) refresh()

    width: 320
    height: content.implicitHeight + 2 * Theme.space.s5

    Glass {
        anchors.fill: parent
        tint: Theme.color.material.thick.tint
        radius: Theme.radius.panel
        shadow: Theme.color.shadow.window
    }

    MouseArea {
        anchors.fill: parent
    }

    Column {
        id: content
        x: Theme.space.s5
        y: Theme.space.s5
        width: parent.width - 2 * Theme.space.s5
        spacing: Theme.space.s3

        Label {
            width: parent.width
            text: "Force Quit Applications"
            style: Theme.text.headline
        }
        Label {
            width: parent.width
            wrapMode: Text.Wrap
            text: "If an app doesn't respond for a while, select its name and click Force Quit."
            style: Theme.text.callout
            color: Theme.color.label.secondary
        }

        // The list, in a well as a Mac's is.
        Rectangle {
            width: parent.width
            height: Math.max(rows.implicitHeight, 3 * 28) + 2 * Theme.space.s1
            radius: Theme.radius.control
            color: Theme.color.bg.control
            border.width: 1
            border.color: Theme.color.border

            Label {
                visible: panel.running.length === 0
                anchors.centerIn: parent
                text: "No apps are open"
                color: Theme.color.label.secondary
            }

            Column {
                id: rows
                x: Theme.space.s1
                y: Theme.space.s1
                width: parent.width - 2 * Theme.space.s1

                Repeater {
                    model: panel.running
                    Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool chosen: index === panel.current
                        width: rows.width
                        height: 28
                        radius: Theme.radius.control - 2
                        color: chosen ? Theme.accent.bg : "transparent"

                        AppTile {
                            id: tile
                            x: Theme.space.s1
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22
                            height: 22
                            tiled: Theme.tileIcons.includes(row.modelData.icon)
                            IconImage {
                                anchors.fill: parent
                                source: Quickshell.iconPath(row.modelData.icon, "application-x-executable")
                            }
                        }
                        Label {
                            anchors { left: tile.right; leftMargin: Theme.space.s2; right: parent.right; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                            text: row.modelData.name
                            elide: Text.ElideRight
                            color: row.chosen ? Theme.accent.fg : Theme.color.label.primary
                        }
                        MouseArea {
                            anchors.fill: parent
                            onPressed: panel.current = row.index
                            onDoubleClicked: panel.accept()
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: quit.height

            PushButton {
                id: quit
                anchors.right: parent.right
                width: 110
                text: "Force Quit"
                primary: true
                enabled: panel.running.length > 0
                onClicked: panel.accept()
            }
        }
    }
}
