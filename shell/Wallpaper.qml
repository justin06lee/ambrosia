import Quickshell
import Quickshell.Wayland
import QtQuick
import Ambrosia

// The desktop picture, on the background layer under every window.
PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "black"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "ambrosia-wallpaper"

    Image {
        anchors.fill: parent
        // Installed beside the shell; AMBROSIA_WALLPAPERS points a dev checkout elsewhere.
        source: "file://" + (Quickshell.env("AMBROSIA_WALLPAPERS") || Quickshell.shellDir + "/../wallpapers")
            + (Theme.dark ? "/nectar-night.png" : "/nectar-day.png")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
    }
}
