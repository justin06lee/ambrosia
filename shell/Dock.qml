import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import Ambrosia

// The Dock: pinned apps, then the others that have windows, then Downloads
// and the Trash. A dot marks running apps. Click to open or bring forward;
// right-click for New Window, Keep in Dock and Quit. Windows maximize above
// it. The window is taller than the Dock to make room for the name tooltip,
// but only the Dock itself takes clicks.
PanelWindow {
    id: dock

    readonly property int icon: Theme.size.dock.icon
    readonly property int pad: Theme.size.dock.padding
    readonly property int tipRoom: 40

    anchors { bottom: true; left: true; right: true }
    implicitHeight: body.height + Theme.size.dock.margin + tipRoom
    exclusiveZone: body.height + Theme.size.dock.margin
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "ambrosia-dock"
    mask: Region { item: body }
    BackgroundEffect.blurRegion: Region { item: body; radius: Theme.radius.dock }

    Item {
        id: body
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.size.dock.margin }
        width: apps.width + 2 * dock.pad
        height: dock.icon + 2 * dock.pad

        Glass {
            anchors.fill: parent
            tint: Theme.color.material.regular.tint
            radius: Theme.radius.dock
            shadow: Theme.color.shadow.panel
        }

        Row {
            id: apps
            x: dock.pad
            y: dock.pad
            spacing: Theme.size.dock.gap

            Repeater {
                model: Apps.tasks

                DockItem {
                    id: appItem
                    required property var model
                    required property int index
                    readonly property var entry: Apps.entryFor(model.AppId, model.AppName)

                    name: model.AppName || entry?.name || ""
                    iconSource: Quickshell.iconPath(entry?.icon ?? "", "application-x-executable")
                    running: model.IsWindow === true || (model.ChildCount ?? 0) > 0
                    attention: model.IsDemandingAttention === true
                    starting: model.IsStartup === true
                    onClicked: Apps.activate(index)
                    onMenuRequested: (x, y) => {
                        const row = index;
                        const id = entry?.id ?? model.AppId;
                        const items = [];
                        if (appItem.running) items.push({ text: "New Window", action: () => Apps.newWindow(row) });
                        else items.push({ text: "Open", action: () => Apps.activate(row) });
                        items.push({ separator: true });
                        items.push({
                            text: "Keep in Dock", checked: Apps.isPinned(id),
                            action: () => Apps.isPinned(id) ? Apps.unpin(id) : Apps.pin(id),
                        });
                        if (appItem.running) {
                            items.push({ separator: true });
                            items.push({ text: "Quit", action: () => Apps.quit(row) });
                        }
                        dock.openMenu(appItem, items);
                    }
                }
            }

            Rectangle {
                width: 1
                height: dock.icon - 4
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.color.separator
            }

            DockItem {
                name: "Downloads"
                glyph: "download"
                onClicked: Session.open(Quickshell.env("HOME") + "/Downloads")
            }

            DockItem {
                id: trash
                name: "Trash"
                glyph: "trash"
                onClicked: Session.open("trash:/")
                onMenuRequested: dock.openMenu(trash, [
                    { text: "Open", action: () => Session.open("trash:/") },
                    { separator: true },
                    { text: "Empty Trash…", action: () => Popups.confirm(dock.screen, {
                        title: "Are you sure you want to permanently erase the items in the Trash?",
                        text: "You can't undo this action.", accept: "Empty Trash",
                        action: () => Quickshell.execDetached(["kioclient", "empty-trash"]) }) },
                ])
            }
        }
    }

    // The tooltip: the name of the app under the pointer, above it.
    Rectangle {
        id: tip
        property Item over: null
        visible: over !== null && !Popups.menuOpen
        x: over ? over.mapToItem(dock.contentItem, over.width / 2, 0).x - width / 2 : 0
        y: body.y - height - Theme.space.s3
        width: tipLabel.implicitWidth + 2 * Theme.space.s3 - 4
        height: tipLabel.implicitHeight + 6
        radius: Theme.radius.tooltip
        color: Theme.color.bg.elevated
        border.width: 0.5
        border.color: Theme.color.glass.edge

        Label {
            id: tipLabel
            anchors.centerIn: parent
            text: tip.over?.name ?? ""
        }
    }

    // A menu above an item, opened on the Overlay of this screen.
    function openMenu(item, items) {
        const point = item.mapToItem(null, item.width / 2, 0);
        const screenY = dock.screen.height - dock.height + point.y;
        // The Overlay starts below the menu bar; menus are placed in its frame.
        const menuHeight = items.reduce((h, entry) => h + (entry.separator ? 2 * Theme.space.s1_5 + 1 : Theme.size.row.compact), 2 * Theme.space.s1_5);
        Popups.openMenu(dock.screen, "dock", items, point.x - 118, screenY - Theme.size.menubar.height - menuHeight - Theme.space.s2);
    }

    component DockItem: Item {
        id: item

        property string name
        property string iconSource
        property string glyph
        property bool running
        property bool attention
        property bool starting
        signal clicked
        signal menuRequested(real x, real y)

        width: dock.icon
        height: dock.icon

        Item {
            id: lift
            width: parent.width
            height: parent.height
            y: area.pressed ? -2 : area.containsMouse ? -6 : 0
            scale: area.pressed ? 0.94 : 1
            Behavior on y { SpringAnimation { spring: 5; damping: 0.35 } }
            Behavior on scale { SpringAnimation { spring: 8; damping: 0.5 } }

            IconImage {
                visible: item.glyph === ""
                anchors.fill: parent
                source: item.iconSource
                // A launching app bounces until its window appears.
                SequentialAnimation on y {
                    running: item.starting
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { to: -16; duration: 300; easing.type: Easing.OutQuad }
                    NumberAnimation { to: 0; duration: 300; easing.type: Easing.InQuad }
                }
            }

            // Folders in the Dock: a glyph on a frosted tile.
            Rectangle {
                visible: item.glyph !== ""
                anchors.fill: parent
                radius: width * Theme.radius.iconCorner
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, Theme.dark ? 0.22 : 0.55) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, Theme.dark ? 0.08 : 0.2) }
                }
                border.width: 1
                border.color: Theme.color.glass.rim

                Icon {
                    anchors.centerIn: parent
                    name: item.glyph
                    size: 28
                    color: Theme.color.label.secondary
                }
            }
        }

        Rectangle {
            visible: item.running
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.bottom; topMargin: (dock.pad - height) / 2 }
            width: Theme.size.dock.indicator
            height: width
            radius: width / 2
            color: item.attention ? Theme.color.palette.orange : Theme.color.label.secondary
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onContainsMouseChanged: {
                if (containsMouse) tip.over = item;
                else if (tip.over === item) tip.over = null;
            }
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) item.menuRequested(mouse.x, mouse.y);
                else item.clicked();
            }
            onPressAndHold: item.menuRequested(mouseX, mouseY)
        }
    }
}
