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
// right-click for New Window, Keep in Dock and Quit. Windows maximize clear of
// it. Its size, magnification, side of the screen, hiding, bouncing and dots
// are Settings'. The window is deeper than the Dock to make room for the name
// tooltip and magnified icons, but only the Dock itself takes clicks.
PanelWindow {
    id: dock

    readonly property int icon: Settings.dockSize
    // Padding, gaps and corners keep their proportion to the icons.
    readonly property real proportion: icon / Theme.size.dock.icon
    readonly property int pad: Math.round(Theme.size.dock.padding * proportion)
    readonly property int gap: Math.round(Theme.size.dock.gap * proportion)
    readonly property real corner: Theme.radius.dock * proportion
    readonly property int margin: Theme.size.dock.margin
    readonly property int thickness: icon + 2 * pad

    readonly property string side: Settings.dockPosition
    readonly property bool vertical: side !== "bottom"
    // The room for a magnified icon and, past it, the name tooltip.
    readonly property real swell: Settings.dockMagnification
    readonly property int swellRoom: Math.ceil(swell * icon)
    readonly property int tipRoom: vertical ? 240 : 40
    readonly property real length: vertical ? height : width

    anchors { bottom: true; top: vertical; left: side !== "right"; right: side !== "left" }
    implicitHeight: vertical ? 0 : thickness + margin + swellRoom + tipRoom
    implicitWidth: vertical ? thickness + margin + swellRoom + tipRoom : 0
    exclusiveZone: Settings.dockAutohide ? 0 : thickness + margin
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "ambrosia-dock"
    mask: Region { item: dock.asleep ? edge : hit }
    BackgroundEffect.blurRegion: Region { item: body; radius: dock.corner }

    // Hidden, the Dock is off the edge, and reaching the edge brings it back.
    readonly property bool awake: !Settings.dockAutohide || hover.hovered || Popups.menuOpen
        || dropArea.containsDrag || dragWake.running
    property bool asleep: false
    property real slide: asleep ? thickness + margin : 0
    Behavior on slide { NumberAnimation { duration: Theme.fade.base; easing.type: Easing.InOutQuad } }
    onAwakeChanged: {
        if (awake) {
            sleepSoon.stop();
            asleep = false;
        } else {
            sleepSoon.restart();
        }
    }
    Component.onCompleted: asleep = !awake
    Timer {
        id: sleepSoon
        interval: 350
        onTriggered: dock.asleep = true
    }
    // A drag reaching the edge brings it back for long enough to reach the Trash.
    Timer {
        id: dragWake
        interval: 3000
    }

    HoverHandler {
        id: hover
        // Where the pointer is along the Dock, in the window.
        property real along: 0
        onPointChanged: along = dock.vertical ? point.position.y : point.position.x
    }

    // Where each icon's middle sits at rest, in the window; the pointer's
    // distance from there is what magnifies it, so that the Dock's growing
    // doesn't feed back into it. An icon past the apps is past the separator.
    readonly property int appCount: appRepeater.count
    readonly property real restLength: (appCount + 2) * (icon + gap) + 1 + 2 * pad
    function restMiddle(slot) {
        return (length - restLength) / 2 + pad + slot * (icon + gap) + icon / 2 + (slot >= appCount ? 1 + gap : 0);
    }

    // Icons drawn on a whole Dock tile, as macOS draws its own (the Trash,
    // Files), are shown that much bigger than the icon size: an app icon's
    // body is 0.805 of the tile.
    readonly property real tileArt: 1 / 0.805
    readonly property var tileIcons: ["org.ambrosia.files"]

    // Moves files to the trash. While Files runs it does the moving, so Edit >
    // Undo there can put them back; KIO's own move (kioclient) can't be undone.
    function trash(urls) {
        Quickshell.execDetached(["sh", "-c",
            'busctl --user --auto-start=no call org.ambrosia.files /org/ambrosia/files org.ambrosia.Files Trash as "$#" "$@" >/dev/null 2>&1'
            + ' || exec kioclient move "$@" trash:/', "sh"].concat(urls));
    }

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
        x: dock.side === "left" ? dock.margin - dock.slide
            : dock.side === "right" ? dock.width - dock.margin - width + dock.slide
            : (dock.width - width) / 2
        y: dock.vertical ? (dock.height - height) / 2 : dock.height - dock.margin - height + dock.slide
        width: dock.vertical ? dock.thickness : apps.width + 2 * dock.pad
        height: dock.vertical ? apps.height + 2 * dock.pad : dock.thickness

        Glass {
            anchors.fill: parent
            tint: Theme.color.material.regular.tint
            radius: dock.corner
            shadow: Theme.color.shadow.panel
            ring: true
        }

        Grid {
            id: apps
            x: dock.pad
            y: dock.pad
            columns: dock.vertical ? 1 : 1000
            spacing: dock.gap
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            Repeater {
                id: appRepeater
                model: Apps.tasks

                DockItem {
                    id: appItem
                    required property var model
                    required property int index
                    readonly property var entry: Apps.entryFor(model.AppId, model.AppName)
                    readonly property string iconName: entry?.icon ?? ""

                    slot: index
                    name: model.AppName || entry?.name || ""
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

                    // Where the app's windows minimize to, the icon at rest.
                    function publish() {
                        if (hover.hovered || dock.asleep)
                            return;
                        const rect = mapToItem(null, 0, 0, width, height);
                        Apps.tasks.requestPublishDelegateGeometry(Apps.tasks.makeModelIndex(index),
                            Qt.rect(rect.x, rect.y, rect.width, rect.height), appItem);
                    }
                    Timer {
                        id: publishSoon
                        interval: 300
                        onTriggered: appItem.publish()
                    }
                    onXChanged: publishSoon.restart()
                    onYChanged: publishSoon.restart()
                    onRunningChanged: publishSoon.restart()
                    Component.onCompleted: publishSoon.restart()
                }
            }

            Rectangle {
                width: dock.vertical ? dock.icon - 4 : 1
                height: dock.vertical ? 1 : dock.icon - 4
                color: Theme.color.separator
            }

            DockItem {
                slot: dock.appCount
                name: "Downloads"
                glyph: "download"
                glyphColor: Theme.accent.text
                onClicked: Session.open(Quickshell.env("HOME") + "/Downloads")
            }

            DockItem {
                id: trash
                slot: dock.appCount + 1
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
                        dock.trash(Array.from(drop.urls, url => url.toString()));
                        drop.accept(Qt.MoveAction);
                    }
                }
            }
        }
    }

    // What takes clicks: the Dock, the room a magnified icon reaches into while
    // the pointer's on it, and, when it hides, down to the screen's edge so
    // that the pointer can leave it that way without it going.
    Item {
        readonly property real beyond: hover.hovered ? dock.swellRoom : 0
        readonly property real below: Settings.dockAutohide ? dock.margin : 0
        id: hit
        x: dock.side === "left" ? body.x - below : dock.side === "right" ? body.x - beyond : body.x
        y: dock.vertical ? body.y : body.y - beyond
        width: dock.vertical ? body.width + beyond + below : body.width
        height: dock.vertical ? body.height : body.height + beyond + below
    }
    // The strip along the edge that wakes it.
    Item {
        id: edge
        x: dock.side === "right" ? dock.width - 2 : dock.vertical ? 0 : (dock.width - width) / 2
        y: dock.vertical ? (dock.height - height) / 2 : dock.height - 2
        width: dock.vertical ? 2 : body.width
        height: dock.vertical ? body.height : 2
        DropArea {
            anchors.fill: parent
            onEntered: dragWake.restart()
        }
    }

    // The tooltip: the name of the app under the pointer, above it or beside
    // it. It fades in where it's needed, then follows the pointer from icon to
    // icon.
    Item {
        id: tip
        property Item over: null
        // The item it points at, kept while it fades out.
        property Item at: null
        readonly property bool shown: over !== null && !Popups.menuOpen

        onOverChanged: {
            if (!over) return;
            followX.enabled = followY.enabled = opacity > 0;
            at = over;
            followX.enabled = followY.enabled = true;
        }

        // How far the icon it's on reaches past the Dock.
        readonly property real reach: Theme.space.s3 + ((at?.zoom ?? 1) - 1) * dock.icon
        readonly property real settle: shown ? 0 : 4
        x: dock.side === "left" ? body.x + body.width + reach - settle
            : dock.side === "right" ? body.x - width - reach + settle
            : at ? at.mapToItem(dock.contentItem, at.width / 2, 0).x - width / 2 : 0
        y: !dock.vertical ? body.y - height - reach + settle
            : at ? at.mapToItem(dock.contentItem, 0, at.height / 2).y - height / 2 : 0
        width: tipLabel.implicitWidth + 2 * 10
        height: tipLabel.implicitHeight + 2 * 3
        opacity: shown ? 1 : 0
        visible: opacity > 0

        Behavior on x { id: followX; SpringAnimation { spring: 8; damping: 0.5 } }
        Behavior on y { id: followY; SpringAnimation { spring: 8; damping: 0.5 } }
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

        // The point, towards the Dock: under the middle, or at its side.
        Rectangle {
            x: dock.side === "left" ? -width / 2 + 0.5
                : dock.side === "right" ? tip.width - width / 2 - 0.5
                : (tip.width - width) / 2
            y: dock.vertical ? (tip.height - height) / 2 : tip.height - height / 2 - 0.5
            width: 9
            height: 9
            rotation: dock.side === "left" ? 135 : dock.side === "right" ? -45 : 45
            bottomRightRadius: 2
            color: Theme.color.bg.elevated
        }

        Label {
            id: tipLabel
            anchors.centerIn: parent
            text: tip.at?.name ?? ""
        }
    }

    // A menu above an item, or beside it, opened on the Overlay of this screen.
    function openMenu(item, items) {
        // The Overlay starts below the menu bar; menus are placed in its frame.
        const menuHeight = items.reduce((h, entry) => h + (entry.separator ? 2 * Theme.space.s1_5 + 1 : Theme.size.row.compact), 2 * Theme.space.s1_5);
        if (dock.vertical) {
            const point = item.mapToItem(null, 0, item.height / 2);
            const x = dock.side === "left" ? body.x + body.width + Theme.space.s2
                : dock.screen.width - dock.width + body.x - 236 - Theme.space.s2;
            // A window down this side starts at the Overlay's top, too.
            Popups.openMenu(dock.screen, "dock", items, x, point.y - menuHeight / 2);
            return;
        }
        const point = item.mapToItem(null, item.width / 2, 0);
        const screenY = dock.screen.height - dock.height + point.y;
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
        // Its place along the Dock, and how big the pointer's nearness makes it.
        property int slot: 0
        property real hop: 0
        readonly property real zoomTarget: {
            if (dock.swell <= 0 || !hover.hovered)
                return 1;
            const near = Math.min(1, Math.abs(hover.along - dock.restMiddle(slot)) / (dock.icon * 2.5));
            return 1 + dock.swell * Math.cos(near * Math.PI / 2);
        }
        property real zoom: zoomTarget
        Behavior on zoom { SmoothedAnimation { duration: 90; velocity: -1 } }
        signal clicked
        signal menuRequested(real x, real y)

        width: dock.vertical ? dock.icon : dock.icon * zoom
        height: dock.vertical ? dock.icon * zoom : dock.icon

        Item {
            id: lift
            readonly property real raised: area.pressed ? 2 : area.containsMouse || item.highlighted ? 6 : 0
            property real raisedBy: raised
            Behavior on raisedBy { SpringAnimation { spring: 5; damping: 0.35 } }
            width: dock.icon
            height: dock.icon
            // In the middle of its slot; it grows from the Dock's edge outwards.
            x: (parent.width - width) / 2 + (dock.side === "left" ? raisedBy : dock.side === "right" ? -raisedBy : 0)
            y: (parent.height - height) / 2 - (dock.vertical ? 0 : raisedBy)
            transformOrigin: dock.side === "left" ? Item.Left : dock.side === "right" ? Item.Right : Item.Bottom
            property real pressScale: area.pressed ? 0.94 : 1
            Behavior on pressScale { SpringAnimation { spring: 8; damping: 0.5 } }
            scale: pressScale * item.zoom

            IconImage {
                visible: item.glyph === ""
                // Drawn as large as it will ever show, and scaled down from there.
                readonly property real most: 1 + dock.swell
                x: (parent.width - width) / 2
                y: (parent.height - height) / 2
                width: parent.width * item.art * most
                height: parent.height * item.art * most
                scale: 1 / most
                source: item.iconSource
                layer.enabled: item.highlighted
                layer.effect: MultiEffect { brightness: -0.3 }
                transform: Translate {
                    x: dock.side === "left" ? item.hop : dock.side === "right" ? -item.hop : 0
                    y: dock.vertical ? 0 : -item.hop
                }
            }
            // A launching app bounces until its window appears.
            SequentialAnimation {
                running: item.starting && Settings.dockBounce
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { target: item; property: "hop"; to: 16; duration: 300; easing.type: Easing.OutQuad }
                NumberAnimation { target: item; property: "hop"; to: 0; duration: 300; easing.type: Easing.InQuad }
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
                    size: 28 * dock.proportion
                    weight: 1.75
                    color: item.glyphColor
                }
            }
        }

        Rectangle {
            visible: item.running && Settings.dockIndicators
            x: dock.side === "left" ? -(dock.pad + width) / 2
                : dock.side === "right" ? parent.width + (dock.pad - width) / 2
                : (parent.width - width) / 2
            y: dock.vertical ? (parent.height - height) / 2 : parent.height + (dock.pad - height) / 2
            width: Theme.size.dock.indicator
            height: width
            radius: width / 2
            color: item.attention ? Theme.color.palette.orange : Theme.color.label.secondary
        }

        MouseArea {
            id: area
            // Over the magnified icon, past the Dock.
            readonly property real past: (item.zoom - 1) * dock.icon
            anchors.fill: parent
            anchors.topMargin: dock.vertical ? 0 : -past
            anchors.rightMargin: dock.side === "left" ? -past : 0
            anchors.leftMargin: dock.side === "right" ? -past : 0
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
