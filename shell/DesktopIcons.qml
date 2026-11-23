import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Ambrosia

// What is in ~/Desktop, as icons on the desktop picture, where a Mac keeps
// them: in columns from the screen's top right corner, in order (by name
// unless the desktop's menu says otherwise). A click chooses one (⌘ or Shift
// adds to the choice), a drag over the picture chooses what it crosses, a
// double click opens, the right button has a menu, and what is chosen can be
// dragged into a window or onto the Trash. Files dropped on the picture move
// into the folder.
Item {
    id: desk

    property string folder: Quickshell.env("HOME") + "/Desktop"
    // The screen this is on, for the menus it opens.
    property ShellScreen screen: null
    // Room kept clear of icons at each edge: the menu bar, the Dock.
    property real insetTop: 0
    property real insetBottom: 0
    property real insetLeft: 0
    property real insetRight: 0

    // What is there, each { name, path, kind, modified, icon, spare }, and
    // the paths of the chosen ones.
    property var things: []
    property var chosen: []
    // Something about to appear (a folder just made): chosen once it has.
    property string awaited: ""
    // The right button on the picture itself, at a place in this item.
    signal menuRequested(real x, real y)

    readonly property var shown: {
        const byName = (a, b) => a.name.localeCompare(b.name);
        const list = things.slice();
        if (Settings.desktopSort === "kind")
            list.sort((a, b) => a.kind.localeCompare(b.kind) || byName(a, b));
        else if (Settings.desktopSort === "date")
            list.sort((a, b) => b.modified - a.modified || byName(a, b));
        else
            list.sort(byName);
        return list;
    }

    readonly property int cellWidth: Theme.size.desktop.cellWidth
    readonly property int cellHeight: Theme.size.desktop.cellHeight
    readonly property int margin: Theme.size.desktop.margin
    readonly property int rows: Math.max(1, Math.floor((height - insetTop - insetBottom - 2 * margin) / cellHeight))
    // Down the first column at the right, then the next to its left.
    function place(index) {
        return Qt.point(width - insetRight - margin - (Math.floor(index / rows) + 1) * cellWidth,
            insetTop + margin + (index % rows) * cellHeight);
    }

    function choose(path, adding) {
        if (!adding)
            chosen = [path];
        else if (chosen.includes(path))
            chosen = chosen.filter(other => other !== path);
        else
            chosen = chosen.concat([path]);
    }
    function open() {
        for (const path of chosen)
            Session.open(path);
    }
    function urls() {
        return chosen.map(path => FileKinds.url(path));
    }
    function thingMenu() {
        const one = chosen.length === 1 ? chosen[0] : "";
        return [
            { text: "Open", action: () => desk.open() },
            { separator: true },
            { text: "Move to Trash", action: () => Session.trash(desk.urls()) },
            { separator: true },
            { text: "Show in Files", enabled: one !== "", action: () => Session.reveal(one) },
        ];
    }

    // The folder is read again whenever it changes: the model only watches
    // it; `file` says what kind each thing is, for its icon.
    function read() {
        if (list.running)
            list.again = true;
        else
            list.running = true;
    }
    FolderListModel {
        id: watch
        showDirs: true
        showDotAndDotDot: false
        sortField: FolderListModel.Unsorted
        onCountChanged: reread.restart()
        onStatusChanged: reread.restart()
        onDataChanged: reread.restart()
        onLayoutChanged: reread.restart()
        onModelReset: reread.restart()
    }
    Timer {
        id: reread
        interval: 150
        onTriggered: desk.read()
    }
    // The folder is made first, so there is one to watch.
    Process {
        running: true
        command: ["mkdir", "-p", desk.folder]
        onExited: {
            watch.folder = FileKinds.url(desk.folder);
            desk.read();
        }
    }
    // A line a thing: when it changed, its kind, its name.
    Process {
        id: list
        property bool again: false
        command: ["sh", "-c",
            'cd "$1" 2>/dev/null || exit 0; for name in *; do [ -e "$name" ] || [ -L "$name" ] || continue;'
            + ' printf "%s\\t%s\\t%s\\n" "$(stat -c %Y -- "$name" 2>/dev/null || echo 0)" "$(file -bL --mime-type -- "$name")" "$name"; done',
            "sh", desk.folder]
        stdout: StdioCollector {
            onStreamFinished: {
                desk.things = text.split("\n").map(line => line.split("\t")).filter(parts => parts.length >= 3).map(parts => {
                    const name = parts.slice(2).join("\t");
                    const path = desk.folder + "/" + name;
                    return { name: name, path: path, kind: parts[1], modified: Number(parts[0]),
                        icon: FileKinds.iconFor(parts[1], path), spare: FileKinds.icon(parts[1]) };
                });
                if (desk.awaited && desk.things.some(thing => thing.path === desk.awaited)) {
                    desk.chosen = [desk.awaited];
                    desk.awaited = "";
                } else {
                    desk.chosen = desk.chosen.filter(path => desk.things.some(thing => thing.path === path));
                }
            }
        }
        onExited: {
            if (again) {
                again = false;
                running = true;
            }
        }
    }

    // The picture itself: a press lets go of what was chosen, a drag chooses
    // what it crosses, the right button asks for the desktop's menu.
    MouseArea {
        id: ground
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property point from
        property var before: []
        property bool banding: false

        onPressed: mouse => {
            const adding = mouse.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.ShiftModifier);
            if (!adding)
                desk.chosen = [];
            if (mouse.button === Qt.RightButton) {
                desk.menuRequested(mouse.x, mouse.y);
                return;
            }
            from = Qt.point(mouse.x, mouse.y);
            before = desk.chosen;
            banding = true;
        }
        onPositionChanged: mouse => {
            if (!banding)
                return;
            band.x = Math.min(from.x, mouse.x);
            band.y = Math.min(from.y, mouse.y);
            band.width = Math.abs(mouse.x - from.x);
            band.height = Math.abs(mouse.y - from.y);
            const crossed = [];
            for (let i = 0; i < desk.shown.length; i++) {
                const at = desk.place(i);
                if (at.x < band.x + band.width && at.x + desk.cellWidth > band.x
                        && at.y < band.y + band.height && at.y + desk.cellHeight > band.y)
                    crossed.push(desk.shown[i].path);
            }
            desk.chosen = before.filter(path => !crossed.includes(path)).concat(crossed);
        }
        onReleased: {
            banding = false;
            band.width = band.height = 0;
        }
    }

    // Files dragged here from a window move into the folder (or are copied,
    // if that is what the drag asks for).
    DropArea {
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: drop => {
            const here = FileKinds.url(desk.folder) + "/";
            const urls = Array.from(drop.urls, url => url.toString())
                .filter(url => url.startsWith("file://") && url.slice(0, url.lastIndexOf("/") + 1) !== here);
            if (urls.length === 0)
                return;
            const copy = drop.proposedAction === Qt.CopyAction;
            drop.accept(copy ? Qt.CopyAction : Qt.MoveAction);
            Quickshell.execDetached(["kioclient", copy ? "copy" : "move"].concat(urls).concat([here]));
        }
    }

    Repeater {
        model: desk.shown

        Item {
            id: thing

            required property int index
            required property var modelData
            readonly property bool picked: desk.chosen.includes(modelData.path)
            readonly property bool picture: FileKinds.isPicture(modelData.kind)
            readonly property point at: desk.place(index)
            readonly property int icon: Theme.size.desktop.icon

            x: at.x
            y: at.y
            width: desk.cellWidth
            height: desk.cellHeight

            // What a chosen icon sits on.
            Rectangle {
                anchors.centerIn: frame
                width: thing.icon + 2 * Theme.space.s1
                height: width
                radius: Theme.size.desktop.radius
                color: Qt.alpha(Theme.color.shadow.panel.color, 0.32)
                visible: thing.picked
            }

            Item {
                id: frame
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.space.s1_5
                width: thing.icon
                height: thing.icon

                // A picture is shown as itself, inside a white edge.
                Rectangle {
                    anchors.centerIn: parent
                    width: art.paintedWidth + 2 * Theme.size.desktop.edge
                    height: art.paintedHeight + 2 * Theme.size.desktop.edge
                    color: "white"
                    visible: thing.picture && art.status === Image.Ready && art.source.toString() === thing.modelData.icon
                    layer.enabled: visible
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Theme.color.shadow.panel.color
                        shadowOpacity: 0.35
                        shadowBlur: 0.4
                        shadowVerticalOffset: 1
                    }
                }
                Image {
                    id: art
                    readonly property int inset: thing.picture ? Theme.size.desktop.edge : 0
                    anchors.fill: parent
                    anchors.margins: inset
                    source: thing.modelData.icon
                    sourceSize: Qt.size(2 * thing.icon, 2 * thing.icon)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    // A picture that can't be read wears its kind's icon.
                    onStatusChanged: if (status === Image.Error && thing.modelData.spare) source = thing.modelData.spare
                }
            }

            // Its name, on at most two lines: white on the picture, or on
            // the accent color when chosen.
            Rectangle {
                anchors.centerIn: name
                width: Math.min(name.width, name.contentWidth) + 2 * Theme.space.s1
                height: name.contentHeight + 2
                radius: Theme.radius.control / 2
                color: Theme.accent.bg
                visible: thing.picked
            }
            Label {
                id: name
                anchors.horizontalCenter: parent.horizontalCenter
                y: frame.y + frame.height + Theme.space.s1_5
                width: parent.width - Theme.space.s2
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignTop
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                lineHeight: Theme.text.callout.line
                lineHeightMode: Text.FixedHeight
                text: thing.modelData.name
                style: Theme.text.callout
                font.weight: 500
                color: thing.picked ? Theme.accent.fg : "white"
                layer.enabled: !thing.picked
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Theme.color.shadow.panel.color
                    shadowOpacity: 0.8
                    shadowBlur: 0.3
                    shadowVerticalOffset: 1
                }
            }

            // What a drag carries away: the chosen things' URLs, under a
            // picture of this one.
            Item {
                id: carried
                Drag.active: area.drag.active
                Drag.dragType: Drag.Automatic
                Drag.supportedActions: Qt.MoveAction | Qt.CopyAction | Qt.LinkAction
                Drag.mimeData: ({ "text/uri-list": desk.urls().join("\r\n") })
                Drag.hotSpot.x: thing.width / 2
                Drag.hotSpot.y: thing.icon / 2
                Drag.onDragFinished: {
                    x = 0;
                    y = 0;
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                drag.target: pressedButtons & Qt.LeftButton ? carried : null
                // Chosen already: a plain click narrows the choice to it when
                // let go, so that several can be dragged together.
                property bool narrow: false

                onPressed: mouse => {
                    const adding = mouse.modifiers & (Qt.ControlModifier | Qt.MetaModifier | Qt.ShiftModifier);
                    narrow = false;
                    if (mouse.button === Qt.RightButton) {
                        if (!thing.picked)
                            desk.choose(thing.modelData.path, false);
                        const at = thing.mapToItem(desk, mouse.x, mouse.y);
                        Popups.openMenu(desk.screen ?? Quickshell.screens[0], "desktop", desk.thingMenu(),
                            at.x, at.y - Theme.size.menubar.height);
                        return;
                    }
                    if (adding)
                        desk.choose(thing.modelData.path, true);
                    else if (thing.picked)
                        narrow = true;
                    else
                        desk.choose(thing.modelData.path, false);
                    thing.grabToImage(result => carried.Drag.imageSource = result.url);
                }
                onReleased: {
                    if (narrow && !drag.active)
                        desk.choose(thing.modelData.path, false);
                }
                onDoubleClicked: mouse => {
                    if (mouse.button === Qt.LeftButton)
                        desk.open();
                }
            }
        }
    }

    // The rectangle a drag over the picture draws.
    Rectangle {
        id: band
        visible: ground.banding && (width > 2 || height > 2)
        color: Qt.alpha(Theme.color.shadow.panel.color, 0.2)
        border.color: Qt.alpha("white", 0.6)
        border.width: 1
    }
}
