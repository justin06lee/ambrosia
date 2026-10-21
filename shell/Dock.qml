import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Qt.labs.folderlistmodel
import Ambrosia
import "icons.js" as Icons

// The Dock: pinned apps, then the others that have windows, then Downloads
// and the Trash, which shows full while the trash has anything in it and
// takes files dropped on it. A dot marks running apps. Click to open or bring forward;
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

    // Icons drawn on a whole Dock tile, as macOS draws its own (the Trash,
    // Files), are shown that much bigger than the icon size: an app icon's
    // body is 0.805 of the tile.
    readonly property real tileArt: 1 / 0.805
    readonly property var tileIcons: ["org.ambrosia.files"]
    // Dolphin stands in for Ambrosia's own Files app until there is one.
    readonly property var standIns: ({ "org.kde.dolphin": { name: "Files", icon: "org.ambrosia.files" } })

    // What's in the trash, watched, so the Trash fills and empties with it.
    // The folder is made first, so there's one to watch.
    readonly property string trashDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/Trash/files"
    property bool trashWatched: false
    readonly property bool trashFull: trashWatched && trashFiles.count > 0
    FolderListModel {
        id: trashFiles
        showHidden: true
        showDirs: true
        showDotAndDotDot: false
        sortField: FolderListModel.Unsorted
    }
    Process {
        running: true
        command: ["mkdir", "-p", dock.trashDir]
        onExited: {
            trashFiles.folder = "file://" + dock.trashDir;
            dock.trashWatched = true;
        }
    }

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
            ring: true
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
                    readonly property var standIn: dock.standIns[entry?.id ?? ""] ?? null
                    readonly property string iconName: standIn?.icon ?? entry?.icon ?? ""

                    name: standIn?.name ?? (model.AppName || entry?.name || "")
                    iconSource: Quickshell.iconPath(iconName, "application-x-executable")
                    art: dock.tileIcons.includes(iconName) ? dock.tileArt : 1
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
                glyphColor: Theme.accent.text
                onClicked: Session.open(Quickshell.env("HOME") + "/Downloads")
            }

            DockItem {
                id: trash
                name: "Trash"
                iconSource: `file://${Quickshell.shellDir}/trash-${dock.trashFull ? "full" : "empty"}.svg`
                art: dock.tileArt
                highlighted: dropArea.containsDrag
                onClicked: Session.open("trash:/")
                onMenuRequested: dock.openMenu(trash, [
                    { text: "Open", action: () => Session.open("trash:/") },
                    { separator: true },
                    { text: "Empty Trash…", action: () => Popups.confirm(dock.screen, {
                        title: "Are you sure you want to permanently erase the items in the Trash?",
                        text: "You can't undo this action.", accept: "Empty Trash",
                        action: () => Quickshell.execDetached(["kioclient", "empty-trash"]) }) },
                ])

                // Files dragged onto it go to the trash; it darkens and shows
                // its name while they're over it.
                DropArea {
                    id: dropArea
                    anchors.fill: parent
                    onEntered: drag => {
                        if (!drag.hasUrls) {
                            drag.accepted = false;
                            return;
                        }
                        drag.accept(Qt.MoveAction);
                        tip.over = trash;
                    }
                    onExited: if (tip.over === trash) tip.over = null
                    onDropped: drop => {
                        if (tip.over === trash) tip.over = null;
                        if (!drop.hasUrls) return;
                        Quickshell.execDetached(["kioclient", "move"].concat(Array.from(drop.urls, url => url.toString()), ["trash:/"]));
                        drop.accept(Qt.MoveAction);
                    }
                }
            }
        }
    }

    // The tooltip: the name of the app under the pointer, above it. It fades
    // in where it's needed, then follows the pointer from icon to icon.
    Item {
        id: tip
        property Item over: null
        // The item it points at, kept while it fades out.
        property Item at: null
        readonly property bool shown: over !== null && !Popups.menuOpen

        onOverChanged: {
            if (!over) return;
            follow.enabled = opacity > 0;
            at = over;
            follow.enabled = true;
        }

        x: at ? at.mapToItem(dock.contentItem, at.width / 2, 0).x - width / 2 : 0
        y: body.y - height - Theme.space.s3 + (shown ? 0 : 4)
        width: tipLabel.implicitWidth + 2 * 10
        height: tipLabel.implicitHeight + 2 * 3
        opacity: shown ? 1 : 0
        visible: opacity > 0

        Behavior on x { id: follow; SpringAnimation { spring: 8; damping: 0.5 } }
        Behavior on y { SpringAnimation { spring: 8; damping: 0.5 } }
        Behavior on opacity { NumberAnimation { duration: Theme.fade.fast } }

        Repeater {
            model: Theme.color.shadow.popover.layers

            RectangularShadow {
                required property var modelData
                x: modelData.x
                y: modelData.y
                width: tip.width
                height: tip.height
                radius: Theme.radius.tooltip
                blur: modelData.blur
                color: Qt.alpha(Theme.color.shadow.popover.color, modelData.opacity)
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.tooltip
            color: Theme.color.bg.elevated
            border.width: 0.5
            border.color: Theme.color.glass.edge
        }

        // The point, under the middle.
        Rectangle {
            x: (tip.width - width) / 2
            y: tip.height - height / 2 - 0.5
            width: 9
            height: 9
            rotation: 45
            bottomRightRadius: 2
            color: Theme.color.bg.elevated
        }

        Label {
            id: tipLabel
            anchors.centerIn: parent
            text: tip.at?.name ?? ""
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
        property color glyphColor: Theme.color.label.secondary
        property bool running
        property bool attention
        property bool starting
        // Lifted and darkened, as under a drag that can drop on it.
        property bool highlighted
        // The image's size against the icon's, for art drawn past it.
        property real art: 1
        signal clicked
        signal menuRequested(real x, real y)

        width: dock.icon
        height: dock.icon

        Item {
            id: lift
            width: parent.width
            height: parent.height
            y: area.pressed ? -2 : area.containsMouse || item.highlighted ? -6 : 0
            scale: area.pressed ? 0.94 : 1
            Behavior on y { SpringAnimation { spring: 5; damping: 0.35 } }
            Behavior on scale { SpringAnimation { spring: 8; damping: 0.5 } }

            IconImage {
                visible: item.glyph === ""
                x: (parent.width - width) / 2
                y: (parent.height - height) / 2
                width: parent.width * item.art
                height: parent.height * item.art
                source: item.iconSource
                layer.enabled: item.highlighted
                layer.effect: MultiEffect { brightness: -0.3 }
                // A launching app bounces until its window appears.
                SequentialAnimation on y {
                    running: item.starting
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { to: -16; duration: 300; easing.type: Easing.OutQuad }
                    NumberAnimation { to: 0; duration: 300; easing.type: Easing.InQuad }
                }
            }

            // Folders in the Dock: a glyph on a frosted tile, the app icon's
            // superellipse, ringed with light that's brightest along the top.
            Shape {
                visible: item.glyph !== ""
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        y2: dock.icon
                        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, Theme.dark ? 0.22 : 0.55) }
                        GradientStop { position: 1; color: Qt.rgba(1, 1, 1, Theme.dark ? 0.08 : 0.2) }
                    }
                    PathSvg { path: Icons.squircle(0, 0, dock.icon) }
                }
                ShapePath {
                    strokeColor: "transparent"
                    fillRule: ShapePath.OddEvenFill
                    fillGradient: LinearGradient {
                        y2: dock.icon
                        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.85) }
                        GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.2) }
                        GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.45) }
                    }
                    PathSvg { path: Icons.squircle(0, 0, dock.icon) + Icons.squircle(1.3, 1.3, dock.icon - 2.6) }
                }

                Icon {
                    anchors.centerIn: parent
                    name: item.glyph
                    size: 28
                    weight: 1.75
                    color: item.glyphColor
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
