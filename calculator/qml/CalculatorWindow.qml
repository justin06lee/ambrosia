import QtQuick
import QtQuick.Shapes
import QtQuick.Window
import Ambrosia
import Calculator
import "calc.mjs" as Calc

// Calculator: a Mac's basic one, measured from macOS 27's (the window 230
// by 408, keys 47 across and 54 apart, the display's figures 30 high on a
// line 12 from the right edge). Dark in either appearance, as a Mac's is.
// Frameless: it draws its own corners and lights (KWin draws the shadow;
// App.decorate asks for it), and it can't be resized.
Window {
    id: win

    readonly property int radius: 15
    readonly property int keySize: 47
    readonly property int keyPitch: 54
    readonly property real keysX: 10.5
    readonly property real keysY: 133.5
    readonly property color face: "#212020"

    // What has been typed (calc.mjs), and what the display says of it.
    property var sum: Calc.start()
    readonly property var shown: Calc.display(sum)
    // The key last pressed on the keyboard: its button lights for a moment.
    property string flashed: ""

    property int menusOpen: 0
    readonly property bool looksActive: active || menusOpen > 0 || App.active

    function press(key) {
        sum = Calc.press(sum, key);
    }
    function typed(key) {
        flashed = key;
        unflash.restart();
        press(key);
    }
    function copy() {
        App.copy(Calc.copied(sum));
    }
    function paste() {
        const next = Calc.pasted(sum, App.clipboard());
        if (next)
            sum = next;
    }
    // A key that is also a menu item's shortcut reaches both, and runs once.
    property var lastAct: ({ name: "", at: 0 })
    function act(name, run) {
        const now = Date.now();
        if (lastAct.name === name && now - lastAct.at < 150)
            return;
        lastAct = { name: name, at: now };
        run();
    }
    function keyPressed(event) {
        if (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier))
            return;
        const text = event.text;
        let key = "";
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || text === "=")
            key = "=";
        else if (event.key === Qt.Key_Escape || text === "c" || text === "C")
            key = "ac";
        else if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete)
            key = "back";
        else if ((event.modifiers & Qt.AltModifier) && event.key === Qt.Key_Minus)
            key = "neg"; // ⌥−, as on a Mac
        else if (/^[0-9]$/.test(text))
            key = text;
        else if (text === "." || text === ",")
            key = ".";
        else if (text === "+")
            key = "+";
        else if (text === "-")
            key = "−";
        else if (text === "*" || text === "x" || text === "X")
            key = "×";
        else if (text === "/")
            key = "÷";
        else if (text === "%")
            key = "pct";
        if (key === "")
            return;
        event.accepted = true;
        typed(key);
    }

    width: 230
    height: 408
    minimumWidth: width
    maximumWidth: width
    minimumHeight: height
    maximumHeight: height
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: "Calculator"

    onVisibleChanged: if (visible) App.decorate(win, win.radius)
    Component.onCompleted: {
        if (visible)
            App.decorate(win, win.radius);
        for (const key of App.keys.match(/\[[a-z]+\]|./g) ?? [])
            press(key.startsWith("[") ? key.slice(1, -1) : key);
    }
    onFrameSwapped: App.shown(win)

    Timer {
        id: unflash
        interval: 110
        onTriggered: win.flashed = ""
    }

    Shortcut { sequences: ["Ctrl+C", "Meta+C"]; onActivated: win.act("copy", win.copy) }
    Shortcut { sequences: ["Ctrl+V", "Meta+V"]; onActivated: win.act("paste", win.paste) }
    Shortcut { sequences: ["Ctrl+W", "Meta+W"]; onActivated: win.act("close", win.close) }
    Shortcut { sequences: ["Ctrl+M", "Meta+M"]; onActivated: win.act("minimize", win.showMinimized) }
    Shortcut { sequences: ["Ctrl+Q", "Meta+Q"]; onActivated: Qt.quit() }

    Loader {
        sourceComponent: Component { MenuBar { calculator: win } }
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: win.radius
        color: win.face
        border.width: 0.5
        border.color: "#33ffffff"
        focus: true
        Keys.onPressed: (event) => win.keyPressed(event)

        // The window moves by anywhere that isn't a key.
        DragHandler {
            target: null
            onActiveChanged: if (active) win.startSystemMove()
        }

        // Close and minimize; a calculator doesn't zoom.
        Row {
            id: lights
            x: 19
            y: 20
            spacing: Theme.size.windowControls.gap

            HoverHandler { id: overLights }

            Repeater {
                model: [
                    { color: Theme.windowControls.close, rim: Theme.windowControls.closeRim, glyph: Theme.windowGlyphs.close, act: () => win.close() },
                    { color: Theme.windowControls.minimize, rim: Theme.windowControls.minimizeRim, glyph: Theme.windowGlyphs.minimize, act: () => win.showMinimized() },
                    { color: Theme.windowControls.zoom, rim: Theme.windowControls.zoomRim, glyph: "", off: true, act: () => {} },
                ]

                Rectangle {
                    id: light
                    required property var modelData
                    readonly property bool lit: !modelData.off && (win.looksActive || overLights.hovered)
                    width: Theme.size.windowControls.diameter
                    height: width
                    radius: width / 2
                    color: lit ? modelData.color : "#4a4a46"
                    border.width: 0.5
                    border.color: lit ? modelData.rim : "#40000000"

                    Shape {
                        anchors.fill: parent
                        visible: overLights.hovered && !light.modelData.off
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeWidth: -1
                            fillColor: Qt.rgba(0, 0, 0, Theme.windowGlyphs.opacity)
                            PathSvg { path: light.modelData.glyph }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !light.modelData.off
                        onClicked: light.modelData.act()
                    }
                }
            }
        }

        // The sum that gave the result, small, above it.
        Text {
            x: 12
            width: parent.width - 24
            y: 96 - height
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideLeft
            text: win.shown.top
            color: "#9c9a9a"
            font.family: Theme.uiFont
            font.pixelSize: 13
            renderType: Text.NativeRendering
        }
        // What is being typed, or the result: smaller as it grows longer.
        Text {
            id: figures
            x: 12
            width: parent.width - 24
            height: 40
            y: 127 - height
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignBottom
            text: win.shown.main
            color: "white"
            font.family: Theme.uiFont
            font.pixelSize: 30
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 11
        }

        Repeater {
            model: [
                { name: "back", glyph: "back", kind: "function" }, { name: "ac", label: "AC", kind: "function" },
                { name: "pct", label: "%", kind: "function" }, { name: "÷", label: "÷", kind: "operator" },
                { name: "7", label: "7" }, { name: "8", label: "8" }, { name: "9", label: "9" }, { name: "×", label: "×", kind: "operator" },
                { name: "4", label: "4" }, { name: "5", label: "5" }, { name: "6", label: "6" }, { name: "−", label: "−", kind: "operator" },
                { name: "1", label: "1" }, { name: "2", label: "2" }, { name: "3", label: "3" }, { name: "+", label: "+", kind: "operator" },
                { name: "neg", glyph: "sign" }, { name: "0", label: "0" }, { name: ".", label: "." }, { name: "=", label: "=", kind: "operator" },
            ]

            Key {
                required property var modelData
                required property int index
                x: win.keysX + (index % 4) * win.keyPitch
                y: win.keysY + Math.floor(index / 4) * win.keyPitch
                width: win.keySize
                height: win.keySize
                name: modelData.name
                label: modelData.label ?? ""
                glyph: modelData.glyph ?? ""
                kind: modelData.kind ?? "digit"
                lit: win.looksActive
                flashed: win.flashed === modelData.name
                onPressed: win.press(modelData.name)
            }
        }
    }
}
