import Quickshell
import Quickshell.Wayland
import QtQuick
import Ambrosia

// The desktop picture, on the background layer under every window: what's
// chosen in Settings, each change fading in over the one before.
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
