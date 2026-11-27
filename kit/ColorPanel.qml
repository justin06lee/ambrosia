import QtCore
import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import Qt.labs.platform as Platform
import Ambrosia

// The Colors panel every app of ours shows (Colors.qml shows it), measured
// from macOS 27's in Dark (2026-11-28, raised behind everything by a
// program of our own: its grays are a panel's that isn't in front): 266
// wide; a strip of the ways to choose, each a picture on a 44 by 25 fill
// when chosen; the chosen way's page; a rule; the color itself in a well
// 32 by 28 with the eyedropper under it, and thirty places to keep colors
// in, 17 square and 19 apart. The ways: the wheel (hue round it,
// saturation out from its middle, brightness on the bar under it), the
// sliders (gray, RGB, CMYK or HSB, with figures and the hex), the lists of
// named colors, and the pencils. A Mac's fifth, colors from a picture, is
// not here; nor its opacity bar and color spaces. The window is the
// session's frame around this (a Mac's panel has smaller lights and a
// lower bar). It says `picked` at every change made in it.
Window {
    id: panel

    // The color, as the three it is chosen by (a hue outlives a brightness
    // of nothing, which red, green and blue alone would not keep).
    property real hue: 0.6
    property real saturation: 0.78
    property real brightness: 0.9
    // (`value`: a window's own `color` is its ground.)
    readonly property color value: Qt.hsva(hue, saturation, brightness, 1)
    signal picked(color color)
    // Asked to take a color off the screen (the app's part: KWin's picker).
    signal dropper()
    property bool canDrop: false

    readonly property bool dark: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark
    readonly property QtObject colors: dark ? Theme.darkColors : Theme.lightColors
    readonly property color ground: dark ? "#22201f" : "#ececec"
    readonly property color raised: dark ? "#323030" : "#dcdcdc"
    readonly property color chosenFill: dark ? "#363433" : "#d6d6d6"
    readonly property color field: dark ? "#181717" : "#ffffff"
    readonly property color fieldRim: dark ? "#2b2928" : "#c8c8c8"
    readonly property color rule: dark ? "#3d3b3a" : "#d0d0d0"
    readonly property color cellRim: dark ? "#595756" : "#bdbdbd"
    readonly property color ink: colors.label.primary
    readonly property color faint: dark ? "#9b9a9a" : "#6e6e6e"

    // What is kept from one time to the next, for every app: the way, the
    // kind of sliders, the list, and the colors kept.
    Settings {
        id: kept
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/ambrosia/colors.conf"
        category: "panel"
        property string mode: "wheel"
        property string sliders: "rgb"
        property string list: "basic"
        property string swatches: ""
    }
    property string mode: "wheel"
    property string sliders: "rgb"
    property string list: "basic"
    property var swatches: []
    Component.onCompleted: {
        mode = ["wheel", "sliders", "palettes", "pencils"].includes(kept.mode) ? kept.mode : "wheel";
        sliders = ["gray", "rgb", "cmyk", "hsb"].includes(kept.sliders) ? kept.sliders : "rgb";
        list = kept.list === "web" ? "web" : "basic";
        const saved = kept.swatches.split(",");
        const cells = [];
        for (let at = 0; at < 30; ++at)
            cells.push(/^#[0-9a-f]{6}$/.test(saved[at] ?? "") ? saved[at] : "");
        swatches = cells;
    }
    onModeChanged: kept.mode = mode
    onSlidersChanged: kept.sliders = sliders
    onListChanged: kept.list = list
    function keep(index, value) {
        const cells = swatches.slice();
        cells[index] = value;
        swatches = cells;
        kept.swatches = cells.join(",");
    }

    // A color shown (`tell`: it was chosen here, and whoever asked for the
    // panel hears of it).
    function present(color) {
        take(color, false);
    }
    function take(color, tell) {
        const c = Qt.color(color);
        if (c.hsvSaturation > 0 && c.hsvValue > 0 && c.hsvHue >= 0)
            hue = c.hsvHue;
        saturation = c.hsvSaturation;
        brightness = c.hsvValue;
        if (tell)
            picked(panel.value);
    }
    function set(h, s, v) {
        hue = Math.max(0, Math.min(1, h));
        saturation = Math.max(0, Math.min(1, s));
        brightness = Math.max(0, Math.min(1, v));
        picked(panel.value);
    }
    // One part of the color in the kind of sliders chosen: its name, where
    // it stands of `top`, the colors along its bar (and for cyan, magenta,
    // yellow and black, all four).
    function part(key) {
        const c = panel.value, h = hue, s = saturation, v = brightness;
        switch (key) {
        case "h": return { name: "Hue", top: 360, at: h, stops: [0, 1, 2, 3, 4, 5, 6].map(n => Qt.hsva(n === 6 ? 0 : n / 6, 1, 1, 1)) };
        case "s": return { name: "Saturation", top: 100, at: s, stops: [Qt.hsva(h, 0, v, 1), Qt.hsva(h, 1, v, 1)] };
        case "v": return { name: "Brightness", top: 100, at: v, stops: sliders === "gray" ? ["#000000", "#ffffff"] : ["#000000", Qt.hsva(h, s, 1, 1)] };
        case "r": return { name: "Red", top: 255, at: c.r, stops: [Qt.rgba(0, c.g, c.b, 1), Qt.rgba(1, c.g, c.b, 1)] };
        case "g": return { name: "Green", top: 255, at: c.g, stops: [Qt.rgba(c.r, 0, c.b, 1), Qt.rgba(c.r, 1, c.b, 1)] };
        case "b": return { name: "Blue", top: 255, at: c.b, stops: [Qt.rgba(c.r, c.g, 0, 1), Qt.rgba(c.r, c.g, 1, 1)] };
        }
        const k = 1 - Math.max(c.r, c.g, c.b), d = 1 - k;
        const all = [d > 0 ? (1 - c.r - k) / d : 0, d > 0 ? (1 - c.g - k) / d : 0, d > 0 ? (1 - c.b - k) / d : 0, k];
        const of = (inks) => Qt.rgba((1 - inks[0]) * (1 - inks[3]), (1 - inks[1]) * (1 - inks[3]), (1 - inks[2]) * (1 - inks[3]), 1);
        const at = "cmyk".indexOf(key), none = all.slice(), full = all.slice();
        none[at] = 0;
        full[at] = 1;
        return { name: ["Cyan", "Magenta", "Yellow", "Black"][at], top: 100, at: all[at], stops: [of(none), of(full)], all: all };
    }
    function hex(color) {
        const two = (n) => Math.round(n * 255).toString(16).padStart(2, "0");
        return (two(color.r) + two(color.g) + two(color.b)).toUpperCase();
    }

    // The page of each way is this tall (a Mac's, less its strip).
    readonly property real pageHeight: mode === "wheel" ? 262 : mode === "palettes" ? 248 : 238
    readonly property real tall: 36 + pageHeight + 0.5 + 12 + 55 + 21
    title: "Colors"
    flags: Qt.Tool | Qt.CustomizeWindowHint | Qt.WindowTitleHint | Qt.WindowCloseButtonHint
    width: 266
    height: tall
    minimumWidth: 266
    maximumWidth: 266
    minimumHeight: tall
    maximumHeight: tall
    color: ground

    // ⌘W closes the panel. Not by a Shortcut: the key is the menu's Close
    // too, and with the panel belonging to a document's window Qt takes
    // the two for one window's and hands the key to each in turn, so the
    // document closed. Whatever has the keys here claims it before
    // shortcuts are looked at.
    function claims(event) {
        return (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) && !(event.modifiers & (Qt.ShiftModifier | Qt.AltModifier)) && event.key === Qt.Key_W;
    }

    component Words: Text {
        font.family: Theme.uiFont
        font.pixelSize: 13
        color: panel.ink
        renderType: Text.NativeRendering
    }

    // A bar with a knob on it: `value` 0 to 1 from its left; its ground a
    // run of colors.
    component Bar: Item {
        id: bar
        property real value: 0
        property var stops: []
        property color knob: "white"
        property string name
        signal moved(real value)
        height: 21
        Accessible.role: Accessible.Slider
        Accessible.name: name
        Canvas {
            id: paint
            anchors.fill: parent
            property var stops: bar.stops
            onStopsChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const r = height / 2;
                ctx.beginPath();
                ctx.moveTo(r, 0);
                ctx.lineTo(width - r, 0);
                ctx.arc(width - r, r, r, -Math.PI / 2, Math.PI / 2, false);
                ctx.lineTo(r, height);
                ctx.arc(r, r, r, Math.PI / 2, Math.PI * 1.5, false);
                ctx.closePath();
                const fill = ctx.createLinearGradient(r, 0, width - r, 0);
                for (let at = 0; at < stops.length; ++at)
                    fill.addColorStop(at / Math.max(1, stops.length - 1), stops[at]);
                ctx.fillStyle = fill;
                ctx.fill();
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            border.width: 0.5
            border.color: panel.dark ? "#26ffffff" : "#26000000"
        }
        Rectangle {
            x: bar.value * (bar.width - width)
            width: bar.height
            height: bar.height
            radius: height / 2
            color: "white"
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: height / 2
                color: bar.knob
            }
        }
        MouseArea {
            anchors.fill: parent
            preventStealing: true
            function at(mouse) {
                bar.moved(Math.max(0, Math.min(1, (mouse.x - bar.height / 2) / (bar.width - bar.height))));
            }
            onPressed: (mouse) => at(mouse)
            onPositionChanged: (mouse) => at(mouse)
        }
    }

    // A field of figures: Return or leaving it takes what was typed, the
    // up and down arrows step it.
    component Figure: Rectangle {
        id: figure
        property string value
        property string name
        property bool letters: false
        signal entered(string text)
        signal stepped(int by)
        width: 48
        height: 22
        radius: 6
        color: panel.field
        border.width: input.activeFocus ? 2.5 : 1
        border.color: input.activeFocus ? Theme.accent.highlight : panel.fieldRim
        Accessible.role: Accessible.EditableText
        Accessible.name: name
        onValueChanged: if (!input.activeFocus) input.text = value
        Component.onCompleted: input.text = value
        TextInput {
            Keys.onShortcutOverride: (event) => event.accepted = panel.claims(event)
            id: input
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            horizontalAlignment: TextInput.AlignHCenter
            verticalAlignment: TextInput.AlignVCenter
            font.family: Theme.uiFont
            font.pixelSize: 13
            color: panel.ink
            selectionColor: Theme.accent.highlight
            selectedTextColor: panel.ink
            renderType: Text.NativeRendering
            selectByMouse: true
            clip: true
            maximumLength: figure.letters ? 7 : 4
            onActiveFocusChanged: {
                if (activeFocus)
                    selectAll();
                else
                    commit();
            }
            // What was typed is taken (or, if it is nothing of the kind,
            // given up for what stands).
            function commit() {
                if (text !== figure.value)
                    figure.entered(text);
                text = figure.value;
            }
            function step(by) {
                commit();
                figure.stepped(by);
                text = figure.value;
                selectAll();
            }
            Keys.onReturnPressed: { commit(); selectAll(); }
            Keys.onEnterPressed: { commit(); selectAll(); }
            Keys.onEscapePressed: { text = figure.value; keys.forceActiveFocus(); }
            Keys.onUpPressed: step(1)
            Keys.onDownPressed: step(-1)
        }
    }

    // A pop-up button across the page: its list is the platform's menu.
    component Choice: Rectangle {
        id: choice
        property var items: []
        property string current
        signal chosen(string value)
        height: 24
        radius: 7
        color: panel.raised
        Accessible.role: Accessible.ComboBox
        Accessible.name: label.text
        Words {
            id: label
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: choice.items.find(item => item.value === choice.current)?.text ?? ""
        }
        Shape {
            x: parent.width - 21
            y: 6
            width: 12
            height: 12
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: panel.ink
                strokeWidth: 1.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M3.2 4.6L6 1.9l2.8 2.7M3.2 7.4L6 10.1l2.8-2.7" }
            }
        }
        Item {
            id: under
            y: choice.height + 3
            width: 1
            height: 1
        }
        MouseArea {
            anchors.fill: parent
            onClicked: choiceMenu.open(under)
        }
        Platform.Menu {
            id: choiceMenu
            Instantiator {
                model: choice.items
                delegate: Platform.MenuItem {
                    required property var modelData
                    text: modelData.text
                    checkable: true
                    checked: modelData.value === choice.current
                    onTriggered: choice.chosen(modelData.value)
                }
                onObjectAdded: (index, object) => choiceMenu.insertItem(index, object)
                onObjectRemoved: (index, object) => choiceMenu.removeItem(object)
            }
        }
    }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onShortcutOverride: (event) => event.accepted = panel.claims(event)
        Keys.onPressed: (event) => {
            if (panel.claims(event)) {
                panel.close();
                event.accepted = true;
            }
        }

        // The strip: the ways to choose.
        Row {
            id: strip
            anchors.horizontalCenter: parent.horizontalCenter
            y: 4

            Repeater {
                model: ["wheel", "sliders", "palettes", "pencils"]

                Rectangle {
                    id: way
                    required property string modelData
                    width: 44
                    height: 25
                    radius: 8
                    color: panel.mode === modelData ? panel.chosenFill : "transparent"
                    Accessible.role: Accessible.PageTab
                    Accessible.name: ({ wheel: "Color Wheel", sliders: "Color Sliders", palettes: "Color Palettes", pencils: "Pencils" })[modelData]

                    // The wheel, small.
                    Item {
                        visible: way.modelData === "wheel"
                        anchors.centerIn: parent
                        width: 19
                        height: 19
                        Shape {
                            anchors.fill: parent
                            ShapePath {
                                strokeColor: "transparent"
                                fillGradient: ConicalGradient {
                                    centerX: 9.5; centerY: 9.5; angle: 0
                                    GradientStop { position: 0; color: "#ff3b30" }
                                    GradientStop { position: 0.167; color: "#ffe14a" }
                                    GradientStop { position: 0.333; color: "#34d94a" }
                                    GradientStop { position: 0.5; color: "#3ad7e6" }
                                    GradientStop { position: 0.667; color: "#2f4bf0" }
                                    GradientStop { position: 0.833; color: "#e83ae0" }
                                    GradientStop { position: 1; color: "#ff3b30" }
                                }
                                PathAngleArc { centerX: 9.5; centerY: 9.5; radiusX: 9.5; radiusY: 9.5; startAngle: 0; sweepAngle: 360 }
                            }
                            ShapePath {
                                strokeColor: "transparent"
                                fillGradient: RadialGradient {
                                    centerX: 9.5; centerY: 9.5; centerRadius: 9.5; focalX: 9.5; focalY: 9.5
                                    GradientStop { position: 0; color: "#ffffffff" }
                                    GradientStop { position: 1; color: "#00ffffff" }
                                }
                                PathAngleArc { centerX: 9.5; centerY: 9.5; radiusX: 9.5; radiusY: 9.5; startAngle: 0; sweepAngle: 360 }
                            }
                        }
                    }
                    // Three bars, each with its knob.
                    Column {
                        visible: way.modelData === "sliders"
                        anchors.centerIn: parent
                        spacing: 2
                        Repeater {
                            model: [["#ff9d96", "#ff3b30", 0.35], ["#9ee6a6", "#34c759", 0.5], ["#a2a8ff", "#4a4cf4", 0.62]]
                            Rectangle {
                                required property var modelData
                                width: 22
                                height: 5
                                radius: 2.5
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: modelData[1] }
                                    GradientStop { position: 1; color: modelData[0] }
                                }
                                Rectangle {
                                    x: parent.modelData[2] * 22 - 2
                                    y: -1
                                    width: 4
                                    height: 7
                                    radius: 2
                                    color: "white"
                                }
                            }
                        }
                    }
                    // Squares of color on a card, another behind it.
                    Item {
                        visible: way.modelData === "palettes"
                        anchors.centerIn: parent
                        width: 21
                        height: 20
                        Rectangle { x: 6; y: 6; width: 15; height: 14; radius: 2.5; color: panel.dark ? "#4a4948" : "#8d8d8d"; border.width: 1; border.color: "white" }
                        Rectangle {
                            width: 15
                            height: 14
                            radius: 2.5
                            color: "white"
                            Grid {
                                anchors.centerIn: parent
                                columns: 2
                                spacing: 1.5
                                Repeater {
                                    model: ["#ff3b30", "#34c759", "#ffb800", "#3478f6"]
                                    Rectangle { required property string modelData; width: 5; height: 4.5; radius: 1; color: modelData }
                                }
                            }
                        }
                    }
                    // Pencils in a row, standing in their tray.
                    Item {
                        visible: way.modelData === "pencils"
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        Row {
                            x: 1
                            spacing: 0
                            Repeater {
                                model: ["#ff3b30", "#ff9500", "#ffd60a", "#34c759", "#3478f6", "#af52de"]
                                Item {
                                    required property string modelData
                                    required property int index
                                    width: 3
                                    height: 14
                                    Rectangle { y: 3 + (index % 2); width: 3; height: 12; color: parent.modelData }
                                    Rectangle { x: 0.75; y: (index % 2); width: 1.5; height: 3; color: "#e8c9a0" }
                                }
                            }
                        }
                        Rectangle { y: 13; width: 20; height: 7; radius: 1.5; color: panel.dark ? "#e4e4e4" : "#f6f6f6"; border.width: 0.5; border.color: "#b0b0b0" }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: panel.mode = way.modelData
                    }
                }
            }
        }

        // The page.
        Item {
            id: page
            y: 36
            width: parent.width
            height: panel.pageHeight

            // The wheel: hue round it from three o'clock against the clock,
            // saturation out from its middle; brightness on the bar under it,
            // full at its left.
            Item {
                id: wheel
                visible: panel.mode === "wheel"
                x: 44.5
                y: 30.5
                width: 177
                height: 177
                readonly property real r: width / 2
                Accessible.role: Accessible.Graphic
                Accessible.name: "Color wheel"
                Shape {
                    anchors.fill: parent
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: ConicalGradient {
                            centerX: wheel.r; centerY: wheel.r; angle: 0
                            GradientStop { position: 0; color: "#ff0000" }
                            GradientStop { position: 0.1667; color: "#ffff00" }
                            GradientStop { position: 0.3333; color: "#00ff00" }
                            GradientStop { position: 0.5; color: "#00ffff" }
                            GradientStop { position: 0.6667; color: "#0000ff" }
                            GradientStop { position: 0.8333; color: "#ff00ff" }
                            GradientStop { position: 1; color: "#ff0000" }
                        }
                        PathAngleArc { centerX: wheel.r; centerY: wheel.r; radiusX: wheel.r; radiusY: wheel.r; startAngle: 0; sweepAngle: 360 }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: RadialGradient {
                            centerX: wheel.r; centerY: wheel.r; centerRadius: wheel.r; focalX: wheel.r; focalY: wheel.r
                            GradientStop { position: 0; color: "#ffffffff" }
                            GradientStop { position: 1; color: "#00ffffff" }
                        }
                        PathAngleArc { centerX: wheel.r; centerY: wheel.r; radiusX: wheel.r; radiusY: wheel.r; startAngle: 0; sweepAngle: 360 }
                    }
                }
                // Brightness darkens the whole of it.
                Rectangle {
                    anchors.fill: parent
                    radius: wheel.r
                    color: "black"
                    opacity: 1 - panel.brightness
                }
                // Where the color is.
                Item {
                    x: wheel.r + panel.saturation * wheel.r * Math.cos(panel.hue * 2 * Math.PI) - 7
                    y: wheel.r - panel.saturation * wheel.r * Math.sin(panel.hue * 2 * Math.PI) - 7
                    width: 14
                    height: 14
                    Rectangle { anchors.centerIn: parent; width: 9; height: 9; radius: 4.5; color: "transparent"; border.width: 1; border.color: "black" }
                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 1; height: 14; color: "black" }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 14; height: 1; color: "black" }
                }
                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    function at(mouse) {
                        const dx = mouse.x - wheel.r, dy = wheel.r - mouse.y;
                        const far = Math.sqrt(dx * dx + dy * dy) / wheel.r;
                        let turn = Math.atan2(dy, dx) / (2 * Math.PI);
                        if (turn < 0)
                            turn += 1;
                        panel.set(turn, Math.min(1, far), panel.brightness);
                    }
                    onPressed: (mouse) => {
                        const dx = mouse.x - wheel.r, dy = wheel.r - mouse.y;
                        if (dx * dx + dy * dy > (wheel.r + 3) * (wheel.r + 3)) {
                            mouse.accepted = false;
                            return;
                        }
                        at(mouse);
                    }
                    onPositionChanged: (mouse) => at(mouse)
                }
            }
            Bar {
                visible: panel.mode === "wheel"
                x: 20
                y: 228.5
                width: 226
                height: 22
                name: "Brightness"
                value: 1 - panel.brightness
                stops: [Qt.hsva(panel.hue, panel.saturation, 1, 1), "#000000"]
                knob: panel.value
                onMoved: (value) => panel.set(panel.hue, panel.saturation, 1 - value)
            }

            // The sliders.
            Choice {
                visible: panel.mode === "sliders"
                x: 20
                y: 19
                width: 226
                items: [{ text: "Grayscale Slider", value: "gray" }, { text: "RGB Sliders", value: "rgb" }, { text: "CMYK Sliders", value: "cmyk" }, { text: "HSB Sliders", value: "hsb" }]
                current: panel.sliders
                onChosen: (value) => panel.sliders = value
            }
            Repeater {
                // One row for each part of the color in the kind chosen (the
                // rows stay while the color changes under a held knob: only
                // what each shows is asked anew).
                model: panel.mode !== "sliders" ? [] : panel.sliders === "gray" ? ["v"] : panel.sliders === "hsb" ? ["h", "s", "v"]
                     : panel.sliders === "cmyk" ? ["c", "m", "y", "k"] : ["r", "g", "b"]

                Item {
                    id: part
                    required property string modelData
                    required property int index
                    readonly property var info: panel.part(modelData)
                    // (Four rows stand closer than three.)
                    readonly property real pitch: panel.sliders === "cmyk" ? 40 : 46
                    x: 20
                    y: 52 + index * pitch
                    width: 226
                    height: 38

                    // One part of the color moved to `value` of 1.
                    function move(value) {
                        const to = Math.max(0, Math.min(1, value)), c = panel.value;
                        switch (modelData) {
                        case "h": panel.set(to, panel.saturation, panel.brightness); break;
                        case "s": panel.set(panel.hue, to, panel.brightness); break;
                        case "v": panel.sliders === "gray" ? panel.set(panel.hue, 0, to) : panel.set(panel.hue, panel.saturation, to); break;
                        case "r": panel.take(Qt.rgba(to, c.g, c.b, 1), true); break;
                        case "g": panel.take(Qt.rgba(c.r, to, c.b, 1), true); break;
                        case "b": panel.take(Qt.rgba(c.r, c.g, to, 1), true); break;
                        default: {
                            const all = info.all.slice();
                            all["cmyk".indexOf(modelData)] = to;
                            panel.take(Qt.rgba((1 - all[0]) * (1 - all[3]), (1 - all[1]) * (1 - all[3]), (1 - all[2]) * (1 - all[3]), 1), true);
                        }
                        }
                    }
                    Words {
                        y: -1
                        text: part.info.name
                        color: panel.faint
                    }
                    Bar {
                        y: 17
                        width: 168.5
                        name: part.info.name
                        value: part.info.at
                        stops: part.info.stops
                        knob: panel.value
                        onMoved: (value) => part.move(value)
                    }
                    Figure {
                        x: 177
                        y: 16.5
                        name: part.info.name
                        value: String(Math.round(part.info.at * part.info.top))
                        onEntered: (text) => {
                            const typed = parseFloat(text);
                            if (!isNaN(typed))
                                part.move(typed / part.info.top);
                        }
                        onStepped: (by) => part.move((Math.round(part.info.at * part.info.top) + by) / part.info.top)
                    }
                }
            }
            Words {
                visible: panel.mode === "sliders"
                x: 182.5 - width
                y: 208 - height / 2
                text: "Hex Color #"
                color: panel.faint
            }
            Figure {
                visible: panel.mode === "sliders"
                // (Wider than a Mac's 48: Inter's capitals are.)
                x: 191
                y: 197
                width: 54
                letters: true
                name: "Hex color"
                value: panel.hex(panel.value)
                onEntered: (text) => {
                    let typed = text.trim().replace(/^#/, "");
                    if (/^[0-9a-fA-F]{3}$/.test(typed))
                        typed = typed[0] + typed[0] + typed[1] + typed[1] + typed[2] + typed[2];
                    if (/^[0-9a-fA-F]{6}$/.test(typed))
                        panel.take("#" + typed, true);
                }
            }

            // The lists.
            Choice {
                visible: panel.mode === "palettes"
                x: 20
                y: 19
                width: 226
                items: [{ text: "Basic", value: "basic" }, { text: "Web Safe Colors", value: "web" }]
                current: panel.list
                onChosen: (value) => panel.list = value
            }
            Rectangle {
                id: search
                visible: panel.mode === "palettes"
                x: 20
                y: 53
                width: 226
                height: 24
                radius: 12
                color: panel.dark ? "#1b1b1a" : "#ffffff"
                border.width: 1
                border.color: panel.fieldRim
                Shape {
                    x: 8
                    y: 5
                    width: 14
                    height: 14
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: panel.faint
                        strokeWidth: 1.5
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathSvg { path: "M2 6.2a4.2 4.2 0 1 0 8.4 0a4.2 4.2 0 1 0-8.4 0M9.4 9.4L12.4 12.4" }
                    }
                }
                TextInput {
                    Keys.onShortcutOverride: (event) => event.accepted = panel.claims(event)
                    id: wanted
                    x: 26
                    width: parent.width - 36
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    color: panel.ink
                    selectionColor: Theme.accent.highlight
                    selectedTextColor: panel.ink
                    renderType: Text.NativeRendering
                    selectByMouse: true
                    clip: true
                    Accessible.name: "Search"
                    Keys.onEscapePressed: text = ""
                }
                Words {
                    x: 26
                    anchors.verticalCenter: parent.verticalCenter
                    visible: wanted.text === ""
                    text: "Search"
                    color: panel.faint
                }
            }
            Rectangle {
                visible: panel.mode === "palettes"
                x: 20
                y: 88
                width: 226
                height: 148
                radius: 6
                color: panel.dark ? "#252322" : "#f7f7f7"
                border.width: 1
                border.color: panel.dark ? "#383635" : "#d4d4d4"

                ListView {
                    id: names
                    anchors.fill: parent
                    anchors.margins: 1
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    topMargin: 4
                    bottomMargin: 4
                    readonly property var basic: [["Black", "#000000"], ["Blue", "#0433ff"], ["Brown", "#aa7942"], ["Cyan", "#00fdff"], ["Green", "#00f900"],
                                                  ["Magenta", "#ff40ff"], ["Orange", "#ff9300"], ["Purple", "#942192"], ["Red", "#ff2600"], ["Yellow", "#fffb00"],
                                                  ["Gray", "#929292"], ["White", "#ffffff"]]
                    readonly property var web: {
                        const made = [], steps = ["00", "33", "66", "99", "CC", "FF"];
                        for (const r of steps) {
                            for (const g of steps) {
                                for (const b of steps)
                                    made.push([r + g + b, "#" + (r + g + b).toLowerCase()]);
                            }
                        }
                        return made;
                    }
                    model: {
                        const all = panel.list === "web" ? web : basic, asked = wanted.text.trim().toLowerCase();
                        return asked === "" ? all : all.filter(entry => entry[0].toLowerCase().includes(asked));
                    }
                    delegate: Item {
                        id: named
                        required property var modelData
                        readonly property bool chosen: panel.hex(panel.value).toLowerCase() === modelData[1].slice(1)
                        width: names.width
                        height: 20
                        Accessible.role: Accessible.ListItem
                        Accessible.name: modelData[0]
                        Rectangle {
                            visible: named.chosen
                            x: 4
                            width: parent.width - 8
                            height: parent.height
                            radius: 5
                            color: panel.chosenFill
                        }
                        Rectangle {
                            x: 26
                            y: 1
                            width: 18
                            height: 18
                            radius: 3
                            color: named.modelData[1]
                            border.width: 1
                            border.color: Qt.lighter(named.modelData[1], 1.25)
                        }
                        Words {
                            x: 53
                            anchors.verticalCenter: parent.verticalCenter
                            text: named.modelData[0]
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: panel.take(named.modelData[1], true)
                        }
                    }
                }
            }

            // The pencils: twelve across, four deep (grays; deep, full and
            // pale colors round the wheel), each standing a little lower than
            // the one behind. Ours: no names.
            Item {
                id: pencils
                visible: panel.mode === "pencils"
                x: 20
                y: 44
                width: 226
                height: 183
                clip: true
                readonly property real each: width / 12
                Repeater {
                    model: 48
                    Item {
                        id: pencil
                        required property int index
                        readonly property int row: Math.floor(index / 12)
                        readonly property int column: index % 12
                        readonly property color lead: row === 0 ? Qt.hsva(0, 0, column / 11, 1)
                                                    : Qt.hsva(column / 12, row === 3 ? 0.55 : 1, row === 1 ? 0.5 : 1, 1)
                        x: column * pencils.each
                        y: row * 40
                        z: row
                        width: pencils.each
                        height: pencils.height - y
                        Accessible.role: Accessible.Button
                        Accessible.name: "Pencil " + (index + 1)
                        Shape {
                            anchors.fill: parent
                            preferredRendererType: Shape.CurveRenderer
                            // The wood, the lead's point, the painted body.
                            ShapePath {
                                strokeColor: "transparent"
                                fillColor: "#e3c59c"
                                PathSvg { path: "M" + (pencil.width / 2) + " 0L" + (pencil.width - 0.5) + " 25L0.5 25z" }
                            }
                            ShapePath {
                                strokeColor: "transparent"
                                fillColor: pencil.lead
                                PathSvg { path: "M" + (pencil.width / 2) + " 0L" + (pencil.width / 2 + 3.1) + " 8.5L" + (pencil.width / 2 - 3.1) + " 8.5z" }
                            }
                        }
                        Rectangle {
                            x: 0.5
                            y: 25
                            width: parent.width - 1
                            height: parent.height - 25
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: Qt.darker(pencil.lead, 1.25) }
                                GradientStop { position: 0.35; color: Qt.lighter(pencil.lead, pencil.lead.hsvValue < 0.15 ? 2.6 : 1.12) }
                                GradientStop { position: 0.7; color: pencil.lead }
                                GradientStop { position: 1; color: Qt.darker(pencil.lead, 1.45) }
                            }
                        }
                        MouseArea {
                            // (What shows of it: the row before stands over the rest.)
                            width: parent.width
                            height: pencil.row === 3 ? parent.height : 40
                            onClicked: panel.take(pencil.lead, true)
                        }
                    }
                }
                // The tray's lip along the bottom.
                Rectangle {
                    y: parent.height - 1
                    z: 9
                    width: parent.width
                    height: 1
                    color: panel.rule
                }
            }
        }

        Rectangle {
            x: 20
            y: 36 + panel.pageHeight
            width: 226
            height: 1
            color: panel.rule
        }

        // The color itself; a place to keep colors in.
        Item {
            id: bottom
            y: 36 + panel.pageHeight + 12.5
            width: parent.width
            height: 55

            Rectangle {
                x: 20
                width: 32
                height: 28
                radius: 6
                color: panel.value
                border.width: 1
                border.color: Qt.lighter(panel.value, 1.3)
                Accessible.role: Accessible.Graphic
                Accessible.name: "Current color"
            }
            // The eyedropper: a color off the screen.
            Item {
                visible: panel.canDrop
                x: 26
                y: 34
                width: 20
                height: 20
                Accessible.role: Accessible.Button
                Accessible.name: "Pick a color from the screen"
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: panel.faint
                        strokeWidth: 1.4
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathSvg { path: "M11.2 6.2l2.6 2.6M12.3 7.5L5 14.8l-1.4 2.6 2.6-1.4 7.3-7.3M12.6 4.6a1.9 1.9 0 0 1 2.7 2.7l-1.6 1.6-2.7-2.7z" }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -3
                    onClicked: panel.dropper()
                }
            }
            Repeater {
                model: panel.swatches
                Rectangle {
                    id: cell
                    required property string modelData
                    required property int index
                    x: 57 + (index % 10) * 19
                    y: Math.floor(index / 10) * 19
                    width: 17
                    height: 17
                    radius: 4
                    color: modelData === "" ? "transparent" : modelData
                    border.width: 1
                    border.color: modelData === "" ? panel.cellRim : Qt.lighter(modelData, 1.25)
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData === "" ? "Empty swatch" : "Swatch " + modelData
                    // A click on an empty one keeps the color there; on a full
                    // one takes its color; the other button empties it.
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton)
                                panel.keep(cell.index, "");
                            else if (cell.modelData === "")
                                panel.keep(cell.index, "#" + panel.hex(panel.value).toLowerCase());
                            else
                                panel.take(cell.modelData, true);
                        }
                    }
                }
            }
        }
    }
}
