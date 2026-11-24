import QtQuick
import QtQuick.Effects
import org.kde.kwin as KWin
import org.kde.kwin.private.effects
import org.kde.kirigami as Kirigami
import Ambrosia

// One screen of Mission Control: the wallpaper, the windows spread out by
// KWin's own layout (the one its Overview uses), the desktops' strip under
// the menu bar, and the menu bar and Dock where they were.
Item {
    id: view

    // The effect (main.qml): its mode, whether it is shown, how long a move takes.
    required property QtObject mission
    readonly property QtObject screen: KWin.SceneView.screen
    readonly property bool all: mission.mode === "all"
    // The room between the menu bar and the Dock, from this screen's corner.
    readonly property rect room: {
        const area = KWin.Workspace.clientArea(KWin.Workspace.MaximizeArea ?? 2, screen, KWin.Workspace.currentDesktop);
        return Qt.rect(area.x - screen.geometry.x, area.y - screen.geometry.y, area.width, area.height);
    }
    // 0 the windows where they are, 1 spread out.
    property real spread: mission.shown && expo.ready ? 1 : 0
    Behavior on spread {
        NumberAnimation { duration: view.mission.duration; easing.type: Easing.OutQuart }
    }
    // The window the arrows are on, as a row of the layout, or -1.
    property int chosen: -1
    // A window is being carried, perhaps to another desktop.
    property bool carrying: false

    function leave() {
        mission.hide();
    }

    function pick(window) {
        KWin.Workspace.activeWindow = window;
        leave();
    }

    // The window nearest the chosen one in a direction, or the first.
    function step(dx, dy) {
        let from = chosen >= 0 ? cells.itemAt(chosen) : null;
        if (from && !from.wanted) from = null;
        let best = -1, bestCost = Infinity;
        for (let i = 0; i < cells.count; i++) {
            const cell = cells.itemAt(i);
            if (!cell || !cell.wanted || cell === from) continue;
            if (!from) {
                const cost = cell.y * 10000 + cell.x;
                if (cost < bestCost) { best = i; bestCost = cost; }
                continue;
            }
            const along = (cell.x + cell.width / 2 - from.x - from.width / 2) * dx
                + (cell.y + cell.height / 2 - from.y - from.height / 2) * dy;
            const across = Math.abs((cell.x + cell.width / 2 - from.x - from.width / 2) * dy)
                + Math.abs((cell.y + cell.height / 2 - from.y - from.height / 2) * dx);
            if (along <= 0) continue;
            const cost = along + 2 * across;
            if (cost < bestCost) { best = i; bestCost = cost; }
        }
        if (best >= 0) chosen = best;
    }

    focus: true
    Keys.onPressed: event => {
        event.accepted = true;
        if (event.key === Qt.Key_Escape) leave();
        else if (event.key === Qt.Key_Left) step(-1, 0);
        else if (event.key === Qt.Key_Right) step(1, 0);
        else if (event.key === Qt.Key_Up) step(0, -1);
        else if (event.key === Qt.Key_Down) step(0, 1);
        else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                 && chosen >= 0 && cells.itemAt(chosen)?.wanted) pick(cells.itemAt(chosen).window);
        else event.accepted = false;
    }

    // KWin's colors are the color scheme's: dark when its window color is.
    SystemPalette { id: system }
    Binding { target: Theme; property: "dark"; value: system.window.hslLightness < 0.5 }

    KWin.WindowModel { id: everyWindow }

    // What is on this screen and not minimized, wallpaper and bars included.
    KWin.WindowFilterModel {
        id: onScreen
        windowModel: everyWindow
        screenName: view.screen.name
        minimizedWindows: false
    }

    // Whether a window is the wallpaper (the shell's lowest layer), and
    // whether it is something that stays put above the windows: the menu
    // bar, the Dock, a banner.
    function isBackdrop(window) {
        return window.desktopWindow || window.layer === 0;
    }
    function isFixture(window) {
        return !isBackdrop(window) && window.skipSwitcher && (window.dock || window.layer >= 3);
    }

    Repeater {
        model: onScreen

        delegate: KWin.WindowThumbnail {
            required property QtObject window
            // Read once: a window's layer says nothing when it changes,
            // and a binding that read it would be warned about each time.
            property bool backdrop: false
            property bool fixture: false
            Component.onCompleted: {
                backdrop = view.isBackdrop(window);
                fixture = view.isFixture(window);
            }

            wId: window.internalId
            x: window.x - view.screen.geometry.x
            y: window.y - view.screen.geometry.y
            width: window.width
            height: window.height
            z: backdrop ? 0 : 4
            visible: backdrop || fixture
        }
    }

    // Glass behind those pictures of the bar and the Dock: the wallpaper
    // again, blurred, in each of their panes (FixtureGlass.qml, which needs
    // Ambrosia's glass effect; without it nothing loads and nothing shows).
    Repeater {
        model: onScreen

        delegate: Loader {
            required property QtObject window

            x: window.x - view.screen.geometry.x
            y: window.y - view.screen.geometry.y
            z: 3
            Component.onCompleted: {
                if (view.isFixture(window))
                    setSource("FixtureGlass.qml", { window: window, windows: onScreen, view: view });
            }
        }
    }

    // A click beside the windows leaves, on the Dock or the menu bar too
    // (their pictures take no clicks).
    MouseArea {
        anchors.fill: parent
        z: 1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: view.leave()
    }

    // One app's windows stand out from a darkened desktop.
    Rectangle {
        anchors.fill: parent
        z: 1
        color: "black"
        opacity: view.all ? 0 : 0.4 * view.spread
        visible: opacity > 0
    }

    // The windows. Drawn a little smaller, toward the Dock, while the
    // desktops' strip shows pictures and so takes more room.
    Item {
        id: stage

        readonly property real squeeze: 1 - (bar.height - bar.closedHeight) / Math.max(1, view.room.height)

        anchors.fill: parent
        z: 2
        transform: Scale {
            origin.x: view.room.x + view.room.width / 2
            origin.y: view.room.y + view.room.height
            xScale: stage.squeeze
            yScale: stage.squeeze
        }

        ExpoLayout {
            id: expo

            // Room for the desktops' strip.
            readonly property int under: view.all ? bar.closedHeight : 0

            x: view.room.x
            y: view.room.y + under
            width: view.room.width
            height: view.room.height - under
            placementMode: ExpoLayout.Rows

            Repeater {
                id: cells

                model: KWin.WindowFilterModel {
                    windowModel: everyWindow
                    screenName: view.screen.name
                    desktop: view.all ? KWin.Workspace.currentDesktop : undefined
                    minimizedWindows: !view.all
                    windowType: KWin.WindowFilterModel.Normal | KWin.WindowFilterModel.Dialog
                }

                delegate: ExpoCell {
                    id: cell

                    required property QtObject window
                    required property int index
                    // The shell's own surfaces are windows to KWin too.
                    readonly property bool wanted: !window.skipSwitcher
                        && (view.all || window.resourceClass === view.mission.appClass)
                    readonly property bool chosen: view.chosen === index
                    readonly property bool settled: view.spread === 1

                    layout: expo
                    shouldLayout: wanted
                    partialActivationFactor: view.spread
                    naturalX: window.x - view.screen.geometry.x
                    naturalY: window.y - view.screen.geometry.y
                    naturalWidth: window.width
                    naturalHeight: window.height
                    persistentKey: window.internalId
                    bottomMargin: Theme.size.mission.gap + Theme.size.mission.label

                    // A window that closes or opens meanwhile: the others
                    // glide to their new places.
                    Behavior on x { enabled: cell.settled; NumberAnimation { duration: view.mission.duration; easing.type: Easing.OutQuart } }
                    Behavior on y { enabled: cell.settled; NumberAnimation { duration: view.mission.duration; easing.type: Easing.OutQuart } }
                    Behavior on width { enabled: cell.settled; NumberAnimation { duration: view.mission.duration; easing.type: Easing.OutQuart } }
                    Behavior on height { enabled: cell.settled; NumberAnimation { duration: view.mission.duration; easing.type: Easing.OutQuart } }

                    contentItem: Item {
                        id: face

                        // How small the window is drawn.
                        readonly property real ratio: cell.window.width > 0 ? width / cell.window.width : 1
                        readonly property bool lit: (over.hovered || cell.chosen) && cell.settled && !carry.active
                        // How far it has been carried from its place.
                        property real dx: carry.active ? carry.activeTranslation.x : 0
                        property real dy: carry.active ? carry.activeTranslation.y : 0
                        Behavior on dx { enabled: !carry.active; NumberAnimation { duration: Theme.spring.snappy.duration; easing.type: Easing.OutCubic } }
                        Behavior on dy { enabled: !carry.active; NumberAnimation { duration: Theme.spring.snappy.duration; easing.type: Easing.OutCubic } }

                        parent: stage
                        visible: cell.wanted
                        z: carry.active || dx !== 0 || dy !== 0 ? 100000 : cell.window.stackingOrder
                        // A minimized window has no place to fly from.
                        opacity: cell.window.minimized ? view.spread : 1
                        transform: Translate { x: face.dx; y: face.dy }

                        RectangularShadow {
                            anchors.fill: parent
                            radius: Theme.radius.window * face.ratio
                            blur: 48 * Math.max(0.5, face.ratio)
                            offset.y: 16 * Math.max(0.5, face.ratio)
                            color: Qt.rgba(0, 0, 0, 0.3)
                            opacity: cell.window.minimized ? 1 : Math.min(1, view.spread * 2)
                        }

                        KWin.WindowThumbnail {
                            anchors.fill: parent
                            wId: cell.window.internalId
                        }

                        // The window the pointer or the arrows are on.
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -Theme.size.mission.ring
                            radius: Theme.radius.window * face.ratio + Theme.size.mission.ring
                            color: "transparent"
                            border.width: Theme.size.mission.ring
                            border.color: Theme.accent.bg
                            visible: face.lit
                        }

                        WindowLabel {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.bottom
                            anchors.topMargin: Theme.size.mission.gap
                            // One app's windows are told apart by their names.
                            visible: (face.lit || !view.all) && !carry.active
                            opacity: view.all ? 1 : view.spread
                            maxWidth: Math.max(parent.width, 240)
                            text: cell.window.caption
                            icon: Kirigami.Icon { anchors.fill: parent; source: cell.window.icon }
                        }

                        HoverHandler {
                            id: over
                            onHoveredChanged: if (hovered) view.chosen = -1
                        }

                        TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: view.pick(cell.window) }

                        // Carried onto a desktop in the strip, the window
                        // moves there; let go anywhere else it comes back.
                        DragHandler {
                            id: carry
                            target: null
                            enabled: view.all && cell.settled
                            grabPermissions: PointerHandler.CanTakeOverFromAnything
                            onActiveChanged: {
                                view.carrying = active;
                                if (active) return;
                                const at = centroid.scenePosition;
                                const row = bar.indexAt(at.x - bar.x, at.y - bar.y);
                                const desktop = row >= 0 ? KWin.Workspace.desktops[row] : null;
                                if (desktop && desktop !== KWin.Workspace.currentDesktop) cell.window.desktops = [desktop];
                            }
                        }
                    }
                }
            }
        }
    }

    // The desktops. Out of the way while one app's windows are shown.
    SpacesBar {
        id: bar

        // Once the pointer has been on it, it stays open, as a Mac's does.
        property bool visited: false

        z: 3
        y: view.room.y - (1 - view.spread) * closedHeight
        width: parent.width
        height: implicitHeight
        visible: view.all
        opacity: view.spread
        aspect: view.width / Math.max(1, view.height)
        open: visited || view.carrying
        spaces: KWin.Workspace.desktops.map(desktop => ({
            name: desktop.name,
            current: desktop === KWin.Workspace.currentDesktop,
            desktop: desktop,
        }))

        HoverHandler { onHoveredChanged: if (hovered) bar.visited = true }

        onPicked: index => {
            KWin.Workspace.currentDesktop = KWin.Workspace.desktops[index];
            view.leave();
        }
        onRemoved: index => KWin.Workspace.removeDesktop(KWin.Workspace.desktops[index])
        onAdded: KWin.Workspace.createDesktop(KWin.Workspace.desktops.length, "")

        // The wallpaper again, blurred, where the bar is.
        backdrop: Item {
            Repeater {
                model: onScreen

                delegate: Loader {
                    required property QtObject window

                    x: window.x - view.screen.geometry.x - bar.x
                    y: window.y - view.screen.geometry.y - bar.y
                    active: false
                    Component.onCompleted: active = view.isBackdrop(window)
                    sourceComponent: KWin.WindowThumbnail {
                        wId: window.internalId
                        width: window.width
                        height: window.height
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            blurEnabled: true
                            blur: 1
                            blurMax: 64
                            saturation: Theme.material.regular.saturate - 1
                        }
                    }
                }
            }
        }

        // A desktop in small: the wallpaper and the windows on it.
        shot: Item {
            id: small

            readonly property QtObject desktop: parent ? parent.entry.desktop : null

            Item {
                width: view.width
                height: view.height
                scale: small.width / Math.max(1, view.width)
                transformOrigin: Item.TopLeft

                Repeater {
                    model: KWin.WindowFilterModel {
                        windowModel: everyWindow
                        screenName: view.screen.name
                        desktop: small.desktop
                        minimizedWindows: false
                    }

                    delegate: KWin.WindowThumbnail {
                        required property QtObject window
                        property bool backdrop: false
                        Component.onCompleted: backdrop = view.isBackdrop(window)

                        wId: window.internalId
                        x: window.x - view.screen.geometry.x
                        y: window.y - view.screen.geometry.y
                        width: window.width
                        height: window.height
                        z: backdrop ? -1 : window.stackingOrder
                        visible: backdrop || !window.skipSwitcher
                    }
                }
            }
        }
    }
}
