import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import Ambrosia

// Screenshots as a Mac takes them: ⇧⌘3 the screen and ⇧⌘4 a part of it
// (`ambrosia screenshot screen|region`, which the shortcuts run) go straight
// to a file on the Desktop named for the moment, and the picture floats in
// the screen's bottom right corner for a few seconds. A click on it opens
// it; left alone it slides away.
//
// Spectacle takes the picture (and draws the crosshair for a part of the
// screen); only its window and its notification are left out.
Scope {
    id: screenshot

    // The file last taken, and whether its thumbnail is up.
    property string file: ""
    property bool up: false

    function take(kind) {
        if (shoot.running) return;
        // The thumbnail of the last one stays out of the next.
        up = false;
        shoot.part = kind === "region";
        shoot.running = true;
    }
    function show(path) {
        file = path;
        up = true;
        linger.restart();
    }

    Process {
        id: shoot

        property bool part: false

        // "Screenshot 2026-11-23 at 10.31.22.png", on the Desktop. A part
        // of the screen given up with Escape leaves no file.
        command: ["sh", "-c",
            'dir=$(xdg-user-dir DESKTOP 2>/dev/null); [ -d "$dir" ] || dir="$HOME/Desktop"; mkdir -p "$dir";'
            + ' file="$dir/Screenshot $(date "+%Y-%m-%d at %H.%M.%S").png";'
            + ' spectacle --background --nonotify "$1" --output "$file" >/dev/null 2>&1; [ -s "$file" ] && printf %s "$file"',
            "sh", part ? "--region" : "--fullscreen"]
        stdout: StdioCollector {
            onStreamFinished: if (text) screenshot.show(text)
        }
    }
    Timer {
        id: linger
        interval: Theme.choreography.screenshot.linger
        onTriggered: screenshot.up = false
    }

    // Made afresh when the first screen changes, as the Dock is.
    Variants {
        model: Quickshell.screens.slice(0, 1)

        PanelWindow {
            id: surface

            required property ShellScreen modelData
            // Room for the shadow round the picture.
            readonly property int room: Theme.space.s8

            screen: modelData
            visible: screenshot.up || thumb.x < width
            anchors { bottom: true; right: true }
            implicitWidth: Theme.size.screenshot.width + Theme.size.screenshot.margin + room
            implicitHeight: Theme.size.screenshot.height + Theme.size.screenshot.margin + room
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "ambrosia-screenshot"
            // Only the picture takes the pointer.
            mask: Region { item: thumb }

            ScreenshotThumb {
                id: thumb

                source: screenshot.file ? "file://" + screenshot.file.split("/").map(encodeURIComponent).join("/") : ""
                y: parent.height - height - Theme.size.screenshot.margin
                // In from the screen's edge, and back out to it.
                x: screenshot.up ? parent.width - width - Theme.size.screenshot.margin : parent.width

                Behavior on x {
                    NumberAnimation {
                        duration: Theme.choreography.screenshot.slide
                        easing.type: Easing.OutCubic
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    // It waits while the pointer is on it.
                    onContainsMouseChanged: containsMouse ? linger.stop() : screenshot.up && linger.restart()
                    onClicked: {
                        screenshot.up = false;
                        Session.open(screenshot.file);
                    }
                }
            }
        }
    }
}
