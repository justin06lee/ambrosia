import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import Ambrosia

// The desktop picture, on the background layer under every window: what's
// chosen in Settings, each change fading in over the one before. A
// right-click on it opens the desktop's menu, as on a Mac, and on the first
// screen what is in ~/Desktop lies on it as icons (DesktopIcons.qml).
PanelWindow {
    id: window

    // Installed beside the shell; AMBROSIA_WALLPAPERS points a dev checkout elsewhere.
    readonly property string folder: Quickshell.env("AMBROSIA_WALLPAPERS") || Quickshell.shellDir + "/../wallpapers"
    readonly property string nectar: "file://" + folder + (Theme.dark ? "/nectar-night.png" : "/nectar-day.png")
    // A picture that wouldn't load: Nectar stands in for it.
    property string failed: ""
    // A color as "#rrggbb", or a picture's URL.
    readonly property string wanted: {
        const choice = Settings.wallpaper;
        if (choice.startsWith("#"))
            return choice;
        if (!choice.startsWith("/") || choice === failed)
            return nectar;
        return "file://" + choice.split("/").map(encodeURIComponent).join("/");
    }
    readonly property int fill: ({
        fit: Image.PreserveAspectFit,
        stretch: Image.Stretch,
        center: Image.Pad,
        tile: Image.Tile,
    })[Settings.wallpaperFit] ?? Image.PreserveAspectCrop

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "black"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "ambrosia-wallpaper"

    onWantedChanged: {
        if (fade.running) {
            fade.stop();
            layers.settle();
        }
        layers.coming.what = wanted;
        layers.tryFade();
    }

    // The first screen has the desktop's icons, as a Mac's main display does.
    readonly property bool first: screen?.name === Quickshell.screens[0]?.name
    // The room the Dock keeps, on its side of the screen.
    readonly property int dockRoom: Settings.dockAutohide ? 0
        : Settings.dockSize + 2 * Math.round(Theme.size.dock.padding * Settings.dockSize / Theme.size.dock.icon) + Theme.size.dock.margin

    // The desktop's own menu. A new folder (in ~/Desktop, named as a Mac
    // names one) appears among the icons, chosen; on a screen without them
    // it is shown in Files.
    function desktopMenu() {
        const sort = (text, by) => ({ text: text, checked: Settings.desktopSort === by, action: () => Settings.desktopSort = by });
        return [
            { text: "New Folder", action: () => newFolder.running = true },
            { separator: true },
            { text: "Change Wallpaper…", action: () => Session.settings("wallpaper") },
            { separator: true },
            { text: "Sort By", submenu: () => [sort("Name", "name"), sort("Kind", "kind"), sort("Date Modified", "date")] },
        ];
    }
    Process {
        id: newFolder
        command: ["sh", "-c",
            'dir="$HOME/Desktop"; name="untitled folder"; n=2;'
            + ' while [ -e "$dir/$name" ]; do name="untitled folder $n"; n=$((n + 1)); done;'
            + ' mkdir -p "$dir/$name" && printf %s "$dir/$name"']
        stdout: StdioCollector {
            onStreamFinished: {
                if (!text) return;
                if (icons.item) icons.item.awaited = text;
                else Session.reveal(text);
            }
        }
    }

    component Layer: Item {
        id: layer
        property string what
        readonly property bool isColor: what.startsWith("#")
        readonly property bool loading: image.status === Image.Loading
        anchors.fill: parent
        onLoadingChanged: {
            if (!loading)
                layers.tryFade();
        }

        Rectangle {
            anchors.fill: parent
            color: layer.isColor ? layer.what : "black"
        }
        Image {
            id: image
            anchors.fill: parent
            // A window not yet sized would load the picture twice.
            source: layer.isColor || window.width <= 0 ? "" : layer.what
            fillMode: window.fill
            // No more of a picture than the screen shows, unless it's drawn as it comes.
            sourceSize: window.fill === Image.Pad || window.fill === Image.Tile ? undefined
                : Qt.size(Math.max(window.width, window.height) * window.devicePixelRatio,
                          Math.max(window.width, window.height) * window.devicePixelRatio)
            autoTransform: true
            asynchronous: true
            smooth: true
            mipmap: true
            onStatusChanged: {
                if (status === Image.Error && source.toString() !== window.nectar)
                    window.failed = decodeURIComponent(source.toString().replace("file://", ""));
            }
        }
    }

    Item {
        id: layers
        anchors.fill: parent

        property Item current: one
        readonly property Item coming: current === one ? two : one

        // Once what's coming is ready, over what's there.
        function tryFade() {
            if (coming.what === "" || coming.what !== window.wanted || coming.loading || fade.running)
                return;
            coming.opacity = 0;
            coming.z = 1;
            current.z = 0;
            fade.start();
        }
        // What came is what's there now.
        function settle() {
            const old = current;
            coming.opacity = 1;
            current = coming;
            old.what = "";
            old.opacity = 0;
        }

        Component.onCompleted: one.what = window.wanted

        Layer {
            id: one
        }
        Layer {
            id: two
            opacity: 0
        }

        // Menus open in the Overlay's frame, which starts below the menu bar;
        // this window starts at the screen's top.
        MouseArea {
            anchors.fill: parent
            z: 2
            acceptedButtons: Qt.RightButton
            onPressed: mouse => Popups.openMenu(window.screen, "desktop", window.desktopMenu(),
                mouse.x, mouse.y - Theme.size.menubar.height)
        }

        Loader {
            id: icons
            anchors.fill: parent
            z: 3
            active: window.first
            sourceComponent: DesktopIcons {
                screen: window.screen
                insetTop: Theme.size.menubar.height
                insetBottom: Settings.dockPosition === "bottom" ? window.dockRoom : 0
                insetLeft: Settings.dockPosition === "left" ? window.dockRoom : 0
                insetRight: Settings.dockPosition === "right" ? window.dockRoom : 0
                onMenuRequested: (x, y) => Popups.openMenu(window.screen, "desktop", window.desktopMenu(),
                    x, y - Theme.size.menubar.height)
            }
        }

        NumberAnimation {
            id: fade
            target: layers.coming
            property: "opacity"
            to: 1
            duration: 400
            easing.type: Easing.InOutQuad
            onFinished: layers.settle()
        }
    }
}
