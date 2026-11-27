import QtCore
import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import QtQuick.Controls.Basic as Controls
import Qt.labs.platform as Platform
import Ambrosia

// The Print panel an app of ours shows (Printing.qml shows it), measured
// from macOS 27's sheet in Dark (2026-11-28, raised behind everything by a
// program of our own): 780 by 373 with corners of 16, over the middle of
// the window it belongs to. Down its left 247 the pages as they will
// print, each 190 wide on white, 10 apart, with which page it is on a pale
// capsule near its foot. Right of them a box with the printer, a box with
// the copies, the pages, the paper and which way up, and along the foot
// PDF, Cancel and Print, 24 tall. A Mac's has more that nothing here is
// behind yet, and so are left out: presets, the pages chosen one by one,
// scaling, and the sections for layout and paper handling.
//
// `job` is what prints: { title, make(file, size), file, save() }. `make`
// writes the PDF for a paper (the size in points, turned when it lies on
// its side) and says whether it could; an app whose document is a PDF
// already gives `file` instead, and its pages are fitted to the paper.
// `save`, if given, is the app's own Export as PDF (`pdf: false`: no PDF
// button at all). The panel is made anew each time (Printing.qml), and is
// gone when it closes.
Window {
    id: panel

    property var job: null

    readonly property bool dark: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark
    readonly property QtObject colors: dark ? Theme.darkColors : Theme.lightColors
    // The Mac's colors with the warmth of what showed through taken out;
    // the light ones are ours.
    readonly property color ground: dark ? "#262524" : "#ececec"
    readonly property color side: dark ? "#2b2a29" : "#e3e3e3"
    readonly property color box: dark ? "#2c2b2a" : "#f5f5f5"
    readonly property color boxRim: dark ? "#333231" : "#dcdcdc"
    readonly property color rule: dark ? "#454442" : "#d6d6d6"
    readonly property color field: dark ? "#191918" : "#ffffff"
    readonly property color fieldRim: dark ? "#363433" : "#c8c8c8"
    readonly property color knob: dark ? "#3c3b39" : "#ffffff"
    readonly property color knobLow: dark ? "#343331" : "#f1f1f1"
    readonly property color push: dark ? "#363533" : "#ffffff"
    readonly property color pushOff: dark ? "#2e2d2b" : "#e9e9e9"
    readonly property color thumb: dark ? "#5e5c5a" : "#b0b0b0"
    readonly property color ink: colors.label.primary
    readonly property color quiet: dark ? "#a3a2a1" : "#6a6a6a"

    // What is kept from one time to the next, for every app.
    Settings {
        id: kept
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/ambrosia/printing.conf"
        category: "panel"
        property string printer: ""
        property string paper: ""
    }

    // The printers, and the one chosen ("" while there is none).
    readonly property var printers: Array.from(Cups.printers)
    property string printer: ""
    readonly property string printerTitle: printers.find(each => each.name === printer)?.title ?? ""
    // The papers the printer takes (every one we name while there is no
    // printer), and the one chosen.
    property var papers: Array.from(Cups.papers())
    property string paper: ""
    readonly property var sheet: papers.find(each => each.key === paper) ?? papers[0]
    property bool landscape: false
    property int copies: 1
    property bool every: true
    property int fromPage: 1
    property int toPage: 1

    // The PDF, and its pages as Cups knows them.
    property url file
    property var shown: ({ id: "", pages: [] })
    readonly property int pageCount: shown.pages.length
    property bool sending: false
    property string trouble: ""
    readonly property bool able: printer !== "" && pageCount > 0 && !sending

    function choosePrinter(name) {
        printer = name;
        kept.printer = name;
        if (name !== "")
            Cups.ask(name);
    }
    function choosePaper(key) {
        if (key === paper)
            return;
        paper = key;
        kept.paper = key;
        make();
    }
    function turn(sideways) {
        if (sideways === landscape)
            return;
        landscape = sideways;
        make();
    }
    // The PDF for the paper as it is now.
    function make() {
        if (!job || !sheet)
            return;
        if (job.make) {
            const was = file, next = Cups.scratch();
            const size = landscape ? Qt.size(sheet.height, sheet.width) : Qt.size(sheet.width, sheet.height);
            if (!job.make(next, size)) {
                trouble = "The document could not be prepared for printing.";
                return;
            }
            const old = shown.id;
            file = next;
            shown = Cups.open(next);
            Cups.close(old);
            Cups.discard(was);
        } else if (shown.id === "") {
            file = job.file;
            shown = Cups.open(job.file);
        }
        fromPage = Math.max(1, Math.min(fromPage, pageCount));
        toPage = every ? pageCount : Math.max(fromPage, Math.min(toPage, pageCount));
    }
    function present() {
        paper = papers.some(each => each.key === kept.paper) ? kept.paper : Cups.usual();
        make();
        toPage = pageCount;
        Cups.look();
    }
    function send() {
        if (!able)
            return;
        trouble = "";
        sending = true;
        const options = { copies: copies, paper: paper };
        if (!every) {
            options.from = fromPage;
            options.to = toPage;
        }
        // A PDF of the app's own isn't made for the paper.
        if (!job.make) {
            options.fit = true;
            options.landscape = landscape;
        }
        Cups.send(printer, file, job.title ?? "Untitled", options);
    }
    function savePdf() {
        const save = job.save;
        close();
        save();
    }

    Connections {
        target: Cups
        function onChanged() {
            // The one chosen last time if it is still there, else the
            // system's, else the first.
            const all = panel.printers;
            if (all.some(each => each.name === panel.printer))
                return;
            const next = all.find(each => each.name === kept.printer) ?? all.find(each => each.isDefault) ?? all[0];
            panel.printer = next?.name ?? "";
            if (panel.printer !== "")
                Cups.ask(panel.printer);
        }
        function onTold(printer, papers, usual) {
            if (printer !== panel.printer)
                return;
            panel.papers = Array.from(papers);
            if (!panel.papers.some(each => each.key === panel.paper)) {
                panel.paper = panel.papers.some(each => each.key === kept.paper) ? kept.paper : usual;
                panel.make();
            }
        }
        function onSent(ok, why) {
            panel.sending = false;
            if (ok)
                panel.close();
            else
                panel.trouble = why !== "" ? why : "The document could not be printed.";
        }
    }

    title: "Print"
    flags: Qt.Dialog | Qt.FramelessWindowHint
    modality: Qt.WindowModal
    width: 780
    height: 373
    minimumWidth: 780
    maximumWidth: 780
    minimumHeight: 373
    maximumHeight: 373
    color: "transparent"

    // A printer added while the panel is up (in Settings, say) is there
    // when the panel is come back to.
    onActiveChanged: if (active) Cups.look()

    property bool shaded: false
    onVisibleChanged: {
        if (visible && !shaded) {
            shaded = true;
            Cups.shade(panel, 16);
        }
        if (!visible) {
            Cups.close(shown.id);
            if (job && job.make)
                Cups.discard(file);
        }
    }

    // ⌘W is the document's Close, and the panel belongs to its window: it
    // is claimed here before shortcuts are looked at (as ColorPanel.qml),
    // and does nothing, as on a Mac with a sheet up.
    function claims(event) {
        return (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) && !(event.modifiers & (Qt.ShiftModifier | Qt.AltModifier))
            && (event.key === Qt.Key_W || event.key === Qt.Key_P || event.key === Qt.Key_Period);
    }
    function typed(event) {
        if (claims(event)) {
            if (event.key === Qt.Key_Period)
                close();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            close();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            send();
            event.accepted = true;
        }
    }

    component Words: Text {
        font.family: Theme.uiFont
        font.pixelSize: 13
        color: panel.ink
        renderType: Text.NativeRendering
    }

    // The up-and-down chevron on a disc, at a row's right end.
    component Chevrons: Rectangle {
        width: 21
        height: 21
        radius: 10.5
        color: panel.knob
        border.width: panel.dark ? 0 : 0.5
        border.color: panel.fieldRim
        Shape {
            anchors.centerIn: parent
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
    }

    // A row's choice: what is chosen, written up to the chevrons, and the
    // menu under them. `items`: [{ text, value }] (no value: a separator;
    // `act`: something done, not chosen).
    component Chooser: Item {
        id: chooser
        property var items: []
        property var current
        property string text
        property string note
        property bool warns: false
        property string name
        signal chosen(var value)

        height: 26
        width: said.implicitWidth + (noted.visible ? noted.implicitWidth + 7 : 0) + (warning.visible ? 21 : 0) + 12 + 21
        activeFocusOnTab: true
        Accessible.role: Accessible.ComboBox
        Accessible.name: name
        Accessible.description: text
        Keys.onSpacePressed: menu.open(under)

        Shape {
            id: warning
            visible: chooser.warns
            x: 0
            y: 5
            width: 16
            height: 16
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: panel.ink
                fillRule: ShapePath.OddEvenFill
                PathSvg { path: "M8 1.6c.6 0 1.1.3 1.4.9l5.4 9.9c.6 1.1-.2 2.4-1.4 2.4H2.6c-1.2 0-2-1.3-1.4-2.4l5.4-9.9c.3-.6.8-.9 1.4-.9zM7.2 5.6v4.2h1.6V5.600zM8 11a1 1 0 1 0 0 2a1 1 0 1 0 0-2z" }
            }
        }
        Words {
            id: said
            x: warning.visible ? 21 : 0
            anchors.verticalCenter: parent.verticalCenter
            text: chooser.text
        }
        Words {
            id: noted
            visible: chooser.note !== ""
            x: said.x + said.implicitWidth + 7
            anchors.baseline: said.baseline
            text: chooser.note
            font.pixelSize: 11
            color: panel.quiet
        }
        Chevrons {
            x: parent.width - 21
            y: 2.5
        }
        Item {
            id: under
            x: parent.width - 21
            y: parent.height + 2
            width: 1
            height: 1
        }
        MouseArea { anchors.fill: parent; onClicked: menu.open(under) }
        Platform.Menu {
            id: menu
            Instantiator {
                model: chooser.items
                delegate: Platform.MenuItem {
                    required property var modelData
                    separator: modelData.value === undefined && modelData.act === undefined
                    text: modelData.text ?? ""
                    checkable: modelData.value !== undefined
                    checked: modelData.value !== undefined && modelData.value === chooser.current
                    onTriggered: modelData.act ? modelData.act() : chooser.chosen(modelData.value)
                }
                onObjectAdded: (index, object) => menu.insertItem(index, object)
                onObjectRemoved: (index, object) => menu.removeItem(object)
            }
        }
    }

    // A field for a number, 60 by 24, its figures against the right.
    component Figure: Rectangle {
        id: number
        property int value: 1
        property int most: 999
        property string name
        signal entered(int value)

        width: 60.5
        height: 24
        radius: 6
        color: panel.field
        border.width: input.activeFocus ? 2.5 : 1
        border.color: input.activeFocus ? Theme.accent.highlight : panel.fieldRim
        opacity: enabled ? 1 : 0.5
        Accessible.role: Accessible.EditableText
        Accessible.name: name
        onValueChanged: if (!input.activeFocus || parseInt(input.text) !== value) input.text = String(value)
        Component.onCompleted: input.text = String(value)

        function take() {
            const typed = parseInt(input.text);
            const to = isNaN(typed) ? value : Math.max(1, Math.min(most, typed));
            input.text = String(to);
            if (to !== value)
                entered(to);
        }
        TextInput {
            id: input
            x: 6
            width: parent.width - 14
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: TextInput.AlignRight
            font.family: Theme.uiFont
            font.pixelSize: 13
            color: panel.ink
            selectionColor: Theme.accent.highlight
            selectedTextColor: panel.ink
            renderType: Text.NativeRendering
            selectByMouse: true
            clip: true
            maximumLength: 4
            validator: IntValidator { bottom: 1; top: 9999 }
            activeFocusOnTab: true
            onActiveFocusChanged: {
                if (activeFocus)
                    selectAll();
                else
                    number.take();
            }
            Keys.onShortcutOverride: (event) => event.accepted = panel.claims(event)
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    number.take();
                panel.typed(event);
            }
            Keys.onUpPressed: { number.take(); if (number.value < number.most) number.entered(number.value + 1); }
            Keys.onDownPressed: { number.take(); if (number.value > 1) number.entered(number.value - 1); }
        }
    }

    // A push button, 24 tall with corners of 6; the one Return presses
    // takes the accent color while the panel is in front.
    component Push: Rectangle {
        id: button
        property string text
        property bool primary: false
        signal pressed()

        width: 70
        height: 24
        radius: 6
        readonly property bool lit: primary && enabled && panel.active
        color: lit ? Theme.accent.bg : enabled ? panel.push : panel.pushOff
        border.width: panel.dark || lit ? 0 : 0.5
        border.color: panel.fieldRim
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: text
        Keys.onSpacePressed: pressed()
        Rectangle {
            anchors.fill: parent
            radius: 6
            visible: area.pressed
            color: panel.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08)
        }
        Words {
            anchors.centerIn: parent
            text: button.text
            color: button.lit ? Theme.accent.fg : panel.ink
            opacity: button.enabled ? 1 : 0.35
        }
        MouseArea { id: area; anchors.fill: parent; onClicked: button.pressed() }
    }

    // Which way up: an arrow for the way the paper goes in, and the page
    // with someone on it.
    component Upright: Shape {
        property bool sideways: false
        width: 18
        height: 14
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: panel.ink
            strokeWidth: 1.2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: "M2.5 11.5V3M0.6 4.9L2.5 3l1.9 1.9"
                    + (sideways ? "M7 2.5h9a1.5 1.5 0 0 1 1.5 1.500v6a1.5 1.5 0 0 1-1.5 1.5H7A1.500 1.5 0 0 1 5.5 10V4A1.500 1.5 0 0 1 7 2.5z"
                                : "M8 1h6a1.5 1.5 0 0 1 1.5 1.500v9a1.5 1.5 0 0 1-1.5 1.5H8A1.500 1.5 0 0 1 6.500 11.500V2.500A1.500 1.5 0 0 1 8 1z")
            }
        }
        ShapePath {
            strokeWidth: -1
            fillColor: panel.ink
            PathSvg {
                path: sideways ? "M8 7a1.500 1.500 0 1 0 3 0a1.500 1.500 0 1 0-3 0zM15.600 4.300c-1.900 0-3.100 1.100-3.100 2.700s1.200 2.700 3.100 2.700z"
                               : "M9.500 5a1.500 1.500 0 1 0 3 0a1.500 1.500 0 1 0-3 0zM8.300 11.100c0-1.900 1.100-3.100 2.700-3.100s2.700 1.200 2.700 3.100z"
            }
        }
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: 16
        color: panel.ground
        border.width: 0.5
        border.color: panel.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.14)

        FocusScope {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onShortcutOverride: (event) => event.accepted = panel.claims(event)
            Keys.onPressed: (event) => panel.typed(event)

            // The pages.
            Rectangle {
                x: 0.5
                y: 0.5
                width: 246.5
                height: parent.height - 1
                topLeftRadius: 15.5
                bottomLeftRadius: 15.5
                color: panel.side

                Flickable {
                    id: sheets
                    anchors.fill: parent
                    anchors.topMargin: 1
                    anchors.bottomMargin: 1
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    contentHeight: stack.height + 20
                    Accessible.role: Accessible.List
                    Accessible.name: "Pages"
                    Controls.ScrollBar.vertical: Controls.ScrollBar {
                        id: bar
                        width: 15
                        policy: sheets.contentHeight > sheets.height ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
                        contentItem: Rectangle {
                            implicitWidth: 11
                            radius: 5.5
                            color: panel.thumb
                            opacity: bar.pressed ? 1 : 0.8
                        }
                    }
                    Column {
                        id: stack
                        x: 19.5
                        y: 9
                        spacing: 10
                        Repeater {
                            model: panel.pageCount
                            delegate: Rectangle {
                                id: leaf
                                required property int index
                                // The paper, the way up it is; the page on
                                // it, which is the paper when the PDF was
                                // made for it.
                                readonly property real paperWidth: panel.landscape ? panel.sheet.height : panel.sheet.width
                                readonly property real paperHeight: panel.landscape ? panel.sheet.width : panel.sheet.height
                                readonly property var page: panel.shown.pages[index] ?? { width: 1, height: 1 }
                                readonly property real fit: Math.min(width / page.width, height / page.height)
                                readonly property bool prints: panel.every || (index + 1 >= panel.fromPage && index + 1 <= panel.toPage)
                                width: 190
                                height: Math.round(190 * paperHeight / paperWidth)
                                color: "#ffffff"
                                Accessible.role: Accessible.ListItem
                                Accessible.name: "Page " + (index + 1) + " of " + panel.pageCount

                                Image {
                                    anchors.centerIn: parent
                                    width: Math.round(leaf.page.width * leaf.fit)
                                    height: Math.round(leaf.page.height * leaf.fit)
                                    sourceSize: Qt.size(width * 2, height * 2)
                                    asynchronous: true
                                    cache: false
                                    source: panel.shown.id !== "" ? "image://printing/" + panel.shown.id + "/" + leaf.index : ""
                                }
                                // A page left out of the range.
                                Rectangle {
                                    anchors.fill: parent
                                    visible: !leaf.prints
                                    color: panel.side
                                    opacity: 0.6
                                }
                                Rectangle {
                                    visible: leaf.height >= 60
                                    x: (parent.width - width) / 2
                                    y: parent.height - 14 - height
                                    width: which.implicitWidth + 28
                                    height: 30
                                    radius: 15
                                    color: "#e8e7e6"
                                    opacity: leaf.prints ? 1 : 0.5
                                    Words {
                                        id: which
                                        anchors.centerIn: parent
                                        text: "Page " + (leaf.index + 1) + " of " + panel.pageCount
                                        color: "#000000"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // The printer.
            Rectangle {
                x: 267
                y: 20
                width: 493
                height: 48
                radius: 12
                color: panel.box
                border.width: 1
                border.color: panel.boxRim

                Words { x: 12; y: 24 - height / 2; text: "Printer" }
                Chooser {
                    x: parent.width - 16.5 - width
                    y: 11
                    name: "Printer"
                    warns: panel.printer === ""
                    text: panel.printer === "" ? (Cups.looked ? "No Printer Selected" : "Looking for Printers…") : panel.printerTitle
                    current: panel.printer
                    items: panel.printers.map(each => ({ text: each.title, value: each.name }))
                        .concat(panel.printers.length > 0 ? [{}] : [], [{ text: "Printers && Scanners Settings…", act: () => Cups.settings() }])
                    onChosen: (value) => panel.choosePrinter(value)
                }
            }

            // How it prints.
            Rectangle {
                x: 267
                y: 80
                width: 493
                height: 226
                radius: 12
                color: panel.box
                border.width: 1
                border.color: panel.boxRim

                Words { x: 12; y: 23 - height / 2; text: "Copies" }
                Figure {
                    x: 391.5
                    y: 11
                    name: "Copies"
                    value: panel.copies
                    onEntered: (value) => panel.copies = value
                }
                // Up and down, a half each.
                Item {
                    x: 460.5
                    y: 11
                    width: 19.5
                    height: 24
                    Accessible.role: Accessible.SpinBox
                    Accessible.name: "Copies"
                    Rectangle { anchors.fill: parent; radius: 6; color: panel.knobLow; border.width: panel.dark ? 0 : 0.5; border.color: panel.fieldRim }
                    Rectangle { width: parent.width; height: 12; topLeftRadius: 6; topRightRadius: 6; color: panel.knob; visible: panel.dark }
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: panel.dark ? "#a8a6a5" : "#4a4a4a"
                            strokeWidth: 1.5
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            PathSvg { path: "M6 8l3.750-3.500L13.500 8M6 16l3.750 3.500L13.500 16" }
                        }
                    }
                    MouseArea { width: parent.width; height: 12; onClicked: if (panel.copies < 999) panel.copies += 1 }
                    MouseArea { y: 12; width: parent.width; height: 12; onClicked: if (panel.copies > 1) panel.copies -= 1 }
                }
                Rectangle { x: 12; y: 43.5; width: parent.width - 24; height: 1; color: panel.rule }

                Words { x: 12; y: 63 - height / 2; text: "Pages" }
                PrefRadio {
                    x: 12
                    y: 79
                    text: panel.pageCount > 1 ? "All " + panel.pageCount + " Pages" : "All Pages"
                    chosen: panel.every
                    onPicked: { panel.every = true; panel.fromPage = 1; panel.toPage = panel.pageCount; }
                }
                PrefRadio {
                    x: 12
                    y: 107
                    text: "Range from"
                    chosen: !panel.every
                    onPicked: panel.every = false
                }
                Figure {
                    x: 113
                    y: 103
                    name: "From page"
                    most: Math.max(1, panel.pageCount)
                    value: panel.fromPage
                    onEntered: (value) => {
                        panel.every = false;
                        panel.fromPage = value;
                        if (panel.toPage < value)
                            panel.toPage = value;
                    }
                }
                Words { x: 181; y: 115 - height / 2; text: "to" }
                Figure {
                    x: 201
                    y: 103
                    name: "To page"
                    most: Math.max(1, panel.pageCount)
                    value: panel.toPage
                    onEntered: (value) => {
                        panel.every = false;
                        panel.toPage = value;
                        if (panel.fromPage > value)
                            panel.fromPage = value;
                    }
                }
                Rectangle { x: 12; y: 136.5; width: parent.width - 24; height: 1; color: panel.rule }

                Words { x: 12; y: 159 - height / 2; text: "Paper Size" }
                Chooser {
                    x: parent.width - 16.5 - width
                    y: 146
                    name: "Paper Size"
                    text: panel.sheet?.name ?? ""
                    note: panel.sheet?.note ?? ""
                    current: panel.paper
                    items: panel.papers.map(each => ({ text: each.name, value: each.key }))
                    onChosen: (value) => panel.choosePaper(value)
                }
                Rectangle { x: 12; y: 181; width: parent.width - 24; height: 1; color: panel.rule }

                Words { x: 12; y: 203.5 - height / 2; text: "Orientation" }
                Row {
                    x: parent.width - 12 - width
                    y: 195.5
                    spacing: 12
                    PrefRadio {
                        id: portrait
                        chosen: !panel.landscape
                        onPicked: panel.turn(false)
                        Accessible.name: "Portrait"
                        implicitWidth: 16 + 6.5 + 18 + 5 + upright.implicitWidth
                        Upright { x: 22.5; y: 1 }
                        Words { id: upright; x: 45.5; anchors.verticalCenter: parent.verticalCenter; text: "Portrait" }
                    }
                    PrefRadio {
                        chosen: panel.landscape
                        onPicked: panel.turn(true)
                        Accessible.name: "Landscape"
                        implicitWidth: 16 + 6.5 + 18 + 5 + sideways.implicitWidth
                        Upright { x: 22.5; y: 1; sideways: true }
                        Words { id: sideways; x: 45.5; anchors.verticalCenter: parent.verticalCenter; text: "Landscape" }
                    }
                }
            }

            // PDF: the app's own Export as PDF, and under the chevron
            // that and Open in Preview.
            Rectangle {
                id: pdf
                visible: panel.job !== null && panel.job.pdf !== false && (panel.job.save !== undefined || panel.job.make !== undefined)
                x: 267
                y: 330
                width: 68
                height: 24
                radius: 6
                color: panel.push
                border.width: panel.dark ? 0 : 0.5
                border.color: panel.fieldRim
                Accessible.role: Accessible.ButtonMenu
                Accessible.name: "PDF"
                Words { x: (50 - width) / 2; anchors.verticalCenter: parent.verticalCenter; text: "PDF" }
                Rectangle { x: 50; y: 4; width: 0.5; height: 16; color: panel.dark ? "#5a5856" : "#c8c8c8" }
                Shape {
                    x: 53
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
                        PathSvg { path: "M2.800 4.600L6 7.700l3.200-3.100" }
                    }
                }
                Item { id: underPdf; y: parent.height + 3; width: 1; height: 1 }
                MouseArea {
                    width: 50
                    height: parent.height
                    onClicked: panel.job.save ? panel.savePdf() : pdfMenu.open(underPdf)
                }
                MouseArea { x: 50; width: 18; height: parent.height; onClicked: pdfMenu.open(underPdf) }
                Platform.Menu {
                    id: pdfMenu
                    Platform.MenuItem {
                        text: "Open in Preview"
                        visible: panel.job !== null && panel.job.make !== undefined
                        enabled: panel.pageCount > 0
                        onTriggered: {
                            Cups.preview(panel.file, panel.job.title ?? "Untitled");
                            panel.close();
                        }
                    }
                    Platform.MenuItem {
                        text: "Save as PDF…"
                        visible: panel.job !== null && panel.job.save !== undefined
                        onTriggered: panel.savePdf()
                    }
                }
            }
            // What went wrong, if something did.
            Words {
                x: 347
                width: 250
                y: 342 - height / 2
                visible: text !== ""
                text: panel.sending ? "Sending to the printer…" : panel.trouble
                font.pixelSize: 11
                color: panel.quiet
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Push {
                x: 608
                y: 330
                text: "Cancel"
                onPressed: panel.close()
            }
            Push {
                x: 690
                y: 330
                text: "Print"
                primary: true
                enabled: panel.able
                onPressed: panel.send()
            }
        }
    }
}
