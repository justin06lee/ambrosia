import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import Ambrosia

// What the volume and brightness keys show: a capsule under the menu bar's
// right end, where the control center opens, gone again a moment after the
// last press.
//
// The keys are Plasma's to handle (plasma-pa's kded module for sound,
// PowerDevil for the display); each then tells plasmashell's
// org.kde.osdService what to show. plasmashell doesn't run here, so nobody
// answers: this listens for those calls on the bus instead (a monitor sees
// a call whether or not anyone takes it) and shows what they say. Nothing is
// shown for a change the keys didn't make, as on a Mac.
Scope {
    id: hud

    property string glyph: "speaker"
    property real level: 0
    property string text: ""
    property bool up: false

    function show(glyph, level, text) {
        // With the control center open its own sliders move; that is enough.
        if (Popups.kind === "controlCenter") return;
        hud.glyph = glyph;
        hud.level = level;
        hud.text = text;
        hud.up = true;
        linger.restart();
    }

    // One line of JSON a call:
    // {"type":"method_call",…,"member":"volumeChanged","payload":{"type":"ii","data":[45,100]}}
    function heard(line) {
        let call;
        try {
            call = JSON.parse(line);
        } catch (error) {
            return;
        }
        const said = call?.payload?.data ?? [];
        switch (call?.member) {
        case "volumeChanged":
            // Percent, and what counts as full (150 with "raise maximum volume").
            show(said[0] > 0 ? "speaker" : "speakerOff", said[0] / (said[1] > 0 ? said[1] : 100), "");
            break;
        case "brightnessChanged":
        case "keyboardBrightnessChanged":
            show("sun", said[0] / 100, "");
            break;
        case "showText":
            // An icon's name and a line: the output that sound moved to.
            if (said[1]) show("", 0, said[1]);
            break;
        case "hide":
            hud.up = false;
            break;
        }
    }

    Process {
        id: listen
        running: true
        command: ["busctl", "--user", "monitor", "--json=short", "--match", "type='method_call',interface='org.kde.osdService'"]
        stdout: SplitParser {
            onRead: line => hud.heard(line)
        }
        // The bus went away under it (a session ending): try again later.
        onExited: again.start()
    }
    Timer {
        id: again
        interval: 5000
        onTriggered: listen.running = true
    }
    Timer {
        id: linger
        interval: Theme.choreography.hud.linger
        onTriggered: hud.up = false
    }

    // To look at it without the keys:
    //   quickshell ipc --path /usr/share/ambrosia/shell call hud -- show volume 45
    // (volume, brightness, or anything else as a line of text; the -- keeps
    // quickshell from reading "show" as its own `ipc show`).
    IpcHandler {
        target: "hud"

        function show(kind: string, percent: int): void {
            if (kind === "volume") hud.heard(JSON.stringify({ member: "volumeChanged", payload: { data: [percent, 100] } }));
            else if (kind === "brightness") hud.heard(JSON.stringify({ member: "brightnessChanged", payload: { data: [percent] } }));
            else hud.heard(JSON.stringify({ member: "showText", payload: { data: ["", kind] } }));
        }
    }

    // Made afresh when the first screen changes, as the Dock is.
    Variants {
        model: Quickshell.screens.slice(0, 1)

        PanelWindow {
            id: surface

            required property ShellScreen modelData

            screen: modelData
            visible: hud.up || panel.opacity > 0
            anchors { top: true; right: true }
            margins.top: Theme.space.s1_5
            // Room for the shadow on the left and below; the right edge is the screen's.
            implicitWidth: Theme.size.hud.width + Theme.space.s8 + Theme.space.s2
            implicitHeight: Theme.size.hud.height + Theme.space.s8
            exclusionMode: ExclusionMode.Normal
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "ambrosia-hud"
            // It only reports: clicks go to what is under it.
            mask: Region { item: nothing }
            BackgroundEffect.blurRegion: Region { item: panel.opacity > 0 ? panel : null; radius: Theme.size.hud.height / 2 }

            Item { id: nothing }

            HudPanel {
                id: panel
                anchors { top: parent.top; right: parent.right; rightMargin: Theme.space.s2 }
                glyph: hud.glyph
                level: hud.level
                text: hud.text
                opacity: hud.up ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: hud.up ? Theme.choreography.hud.fadeIn : Theme.choreography.hud.fadeOut
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [...Theme.fade.curve, 1, 1]
                    }
                }
            }
        }
    }
}
