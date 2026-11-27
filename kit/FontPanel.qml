import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import QtQuick.Controls.Basic as Controls
import Qt.labs.platform as Platform
import Ambrosia

// The Fonts panel an app of ours shows (Fonts.qml shows it), measured from
// macOS 27's in Dark (2026-11-28, raised behind everything by a program of
// our own): 470 by 270, the families down its left half, each after a
// tile 26 square saying Aa in it, 32 apart under the letter they begin
// with, the chosen one on a rounded fill with its name bold and its tile's
// letters in the accent color; right of a hairline, under a bar 38 tall
// holding the size and the search, the family's typefaces 30 apart, each
// written as it looks. A Mac's has its lights in the left half's top and
// no bar of its own (ours is the session's frame around this), collections
// to choose from where ours says All Fonts, and a button for text effects.
// `source` knows the fonts: families, styles(family) and style(family,
// name) saying { weight, italic }. It says `picked` at every change, and which it was.
Window {
    id: panel

    property var source: null
    property string family
    property int weight: 400
    property bool italic: false
    property real size: 12
    // `what`: "family", "face" or "size".
    signal picked(string family, int weight, bool italic, real size, string what)

    readonly property bool dark: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark
    readonly property QtObject colors: dark ? Theme.darkColors : Theme.lightColors
    readonly property color left: dark ? "#262524" : "#ececec"
    readonly property color right: dark ? "#1d1d1c" : "#ffffff"
    readonly property color barFill: dark ? "#252523" : "#f4f4f4"
    readonly property color divider: dark ? "#403f3e" : "#d2d2d2"
    readonly property color tile: dark ? "#1d1c1c" : "#ffffff"
    readonly property color chosenFamily: dark ? "#31302f" : "#dcdcdc"
    readonly property color chosenFace: dark ? "#3d3d3d" : "#dcdcdc"
    readonly property color field: dark ? "#181818" : "#ffffff"
    readonly property color fieldRim: dark ? "#343431" : "#c8c8c8"
    readonly property color capsule: dark ? "#373735" : "#e2e2e2"
    readonly property color ink: colors.label.primary
    readonly property color quiet: dark ? "#a3a2a1" : "#4a4a4a"
    readonly property color faint: dark ? "#6f6e6d" : "#8a8a8a"

    property string wanted: ""
    property bool searching: false
    readonly property var families: source ? Array.from(source.families) : []
    // The families under their letters: { letter } or { family }.
    readonly property var listed: {
        const asked = wanted.trim().toLowerCase(), made = [];
        let last = "";
        for (const name of families) {
            if (asked !== "" && !name.toLowerCase().includes(asked))
                continue;
            const first = name.charAt(0).toUpperCase();
            const letter = /[A-Z]/.test(first) ? first : "#";
            if (letter !== last && asked === "") {
                made.push({ letter: letter, family: "" });
                last = letter;
            }
            made.push({ letter: "", family: name });
        }
        return made;
    }
    // The family's typefaces, lightest first, each upright before its
    // slanted one.
    readonly property var faces: {
        if (!source || family === "")
            return [];
        const all = Array.from(source.styles(family)).map(name => {
            const is = source.style(family, name);
            return { name: name, weight: is.weight, italic: is.italic ? 1 : 0 };
        });
        all.sort((a, b) => a.weight - b.weight || a.italic - b.italic);
        return all.map(each => each.name);
    }
    onFaceChanged: Qt.callLater(panel.revealFace)
    function revealFace() {
        const at = faces.indexOf(face);
        if (at >= 0)
            styles.positionViewAtIndex(at, ListView.Contain);
    }
    // The typeface in use: the one of the weight and slant.
    readonly property string face: {
        for (const name of faces) {
            const is = source.style(family, name);
            if (is.weight === weight && is.italic === italic)
                return name;
        }
        return "";
    }

    // A font shown (nobody is told).
    function present(family, weight, italic, size) {
        // A name the system only answers to (Helvetica) is shown as the
        // family that stands in for it here.
        if (!families.includes(family)) {
            probe.font.family = family;
            if (families.includes(probe.fontInfo.family))
                family = probe.fontInfo.family;
        }
        panel.family = family;
        panel.weight = weight;
        panel.italic = italic;
        panel.size = size;
        Qt.callLater(panel.reveal);
    }
    function reveal() {
        const at = listed.findIndex(entry => entry.family === family);
        if (at >= 0)
            names.positionViewAtIndex(at, ListView.Center);
    }
    function chooseFamily(name) {
        if (name === family)
            return;
        family = name;
        // The typeface of the same weight and slant if the family has it,
        // else its plain one.
        if (face === "") {
            const plain = faces.find(each => { const is = source.style(name, each); return is.weight === 400 && !is.italic; }) ?? faces[0];
            const is = plain !== undefined ? source.style(name, plain) : { weight: 400, italic: false };
            weight = is.weight;
            italic = is.italic;
        }
        picked(family, weight, italic, size, "family");
    }
    function chooseFace(name) {
        const is = source.style(family, name);
        weight = is.weight;
        italic = is.italic;
        picked(family, weight, italic, size, "face");
    }
    function chooseSize(value) {
        const to = Math.max(1, Math.min(1000, Math.round(value * 10) / 10));
        if (isNaN(to))
            return;
        size = to;
        picked(family, weight, italic, size, "size");
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(panel.reveal);
            Qt.callLater(panel.revealFace);
        }
    }
    Text { id: probe; visible: false }

    title: "Fonts"
    flags: Qt.Tool | Qt.CustomizeWindowHint | Qt.WindowTitleHint | Qt.WindowCloseButtonHint
    width: 470
    height: 270
    minimumWidth: 470
    minimumHeight: 200
    maximumWidth: 470
    color: right

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

        // The families.
        Rectangle {
            width: 234.5
            height: parent.height
            color: panel.left

            Words {
                x: 16
                y: 19 - height / 2
                text: "All Fonts"
                font.weight: 700
                color: panel.faint
            }
            ListView {
                id: names
                y: 38
                width: parent.width
                height: parent.height - y
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: panel.listed
                Accessible.role: Accessible.List
                Accessible.name: "Families"
                Controls.ScrollBar.vertical: Controls.ScrollBar {
                    id: thumb
                    width: 11
                    contentItem: Rectangle {
                        implicitWidth: 7
                        radius: 3.5
                        color: panel.dark ? "#585756" : "#b0b0b0"
                        opacity: thumb.active ? 1 : 0.55
                    }
                }
                delegate: Item {
                    id: row
                    required property var modelData
                    readonly property bool heading: modelData.family === ""
                    readonly property bool chosen: !heading && modelData.family === panel.family
                    width: names.width
                    height: heading ? 45 : 32
                    Accessible.role: heading ? Accessible.Heading : Accessible.ListItem
                    Accessible.name: heading ? modelData.letter : modelData.family

                    Words {
                        visible: row.heading
                        x: 16
                        y: 26 - height / 2
                        text: row.modelData.letter
                        font.pixelSize: 11
                        font.weight: 700
                        color: panel.faint
                    }
                    Rectangle {
                        visible: row.chosen
                        x: 12.5
                        y: 0.5
                        width: 193
                        height: 31
                        radius: 8
                        color: panel.chosenFamily
                    }
                    Rectangle {
                        visible: !row.heading
                        x: 13
                        y: 3
                        width: 26
                        height: 26
                        radius: 6
                        color: panel.tile
                        border.width: panel.dark ? 0 : 0.5
                        border.color: panel.fieldRim
                        Text {
                            anchors.centerIn: parent
                            text: "Aa"
                            font.family: row.heading ? Theme.uiFont : row.modelData.family
                            font.pixelSize: 13
                            color: row.chosen ? Theme.accent.bg : panel.ink
                        }
                    }
                    Words {
                        visible: !row.heading
                        x: 45
                        width: 152
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: row.modelData.family
                        font.weight: row.chosen ? 700 : 400
                        color: row.chosen ? panel.ink : panel.quiet
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !row.heading
                        onClicked: panel.chooseFamily(row.modelData.family)
                    }
                }
            }
        }
        Rectangle {
            x: 234.5
            width: 0.5
            height: parent.height
            color: panel.divider
        }

        // The bar: the size, and the search.
        Rectangle {
            x: 235
            width: parent.width - x
            height: 38
            color: panel.barFill

            Rectangle {
                id: sizeField
                x: 4
                y: 9
                width: 55
                height: 20
                radius: 6
                color: panel.field
                border.width: sizeInput.activeFocus ? 2.5 : 1
                border.color: sizeInput.activeFocus ? Theme.accent.highlight : panel.fieldRim
                Accessible.role: Accessible.EditableText
                Accessible.name: "Size"
                readonly property string shownSize: String(Math.round(panel.size * 10) / 10)
                onShownSizeChanged: if (!sizeInput.activeFocus) sizeInput.text = shownSize
                Component.onCompleted: sizeInput.text = shownSize
                TextInput {
                    Keys.onShortcutOverride: (event) => event.accepted = panel.claims(event)
                    id: sizeInput
                    x: 7
                    width: 24
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    color: panel.ink
                    selectionColor: Theme.accent.highlight
                    selectedTextColor: panel.ink
                    renderType: Text.NativeRendering
                    selectByMouse: true
                    clip: true
                    maximumLength: 5
                    function commit() {
                        const typed = parseFloat(text);
                        if (!isNaN(typed) && typed !== panel.size)
                            panel.chooseSize(typed);
                        text = sizeField.shownSize;
                    }
                    onActiveFocusChanged: {
                        if (activeFocus)
                            selectAll();
                        else
                            commit();
                    }
                    Keys.onReturnPressed: { commit(); selectAll(); }
                    Keys.onEnterPressed: { commit(); selectAll(); }
                    Keys.onUpPressed: { commit(); panel.chooseSize(panel.size + 1); text = sizeField.shownSize; selectAll(); }
                    Keys.onDownPressed: { commit(); panel.chooseSize(panel.size - 1); text = sizeField.shownSize; selectAll(); }
                }
                // The usual sizes, under a chevron.
                Rectangle {
                    x: parent.width - 23
                    y: 2.5
                    width: 20
                    height: 15
                    radius: 5
                    color: panel.dark ? "#323232" : "#e4e4e4"
                    Accessible.role: Accessible.Button
                    Accessible.name: "Sizes"
                    Shape {
                        x: 5
                        y: 3
                        width: 10
                        height: 10
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: panel.ink
                            strokeWidth: 1.6
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            PathSvg { path: "M2 3.6L5 6.6L8 3.6" }
                        }
                    }
                    Item {
                        id: underSizes
                        x: -32
                        y: parent.height + 5
                        width: 1
                        height: 1
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: sizes.open(underSizes)
                    }
                }
                Platform.Menu {
                    id: sizes
                    Instantiator {
                        model: [9, 10, 11, 12, 13, 14, 18, 24, 36, 48, 64, 72, 96, 144, 288]
                        delegate: Platform.MenuItem {
                            required property int modelData
                            text: String(modelData)
                            checkable: true
                            checked: modelData === panel.size
                            onTriggered: panel.chooseSize(modelData)
                        }
                        onObjectAdded: (index, object) => sizes.insertItem(index, object)
                        onObjectRemoved: (index, object) => sizes.removeItem(object)
                    }
                }
            }

            // The search: a round button that opens into a field.
            Rectangle {
                id: search
                x: panel.searching ? 66 : parent.width - 44
                y: 8
                width: panel.searching ? parent.width - 66 - 22.5 : 21.5
                height: 21.5
                radius: height / 2
                color: panel.capsule
                Accessible.role: panel.searching ? Accessible.EditableText : Accessible.Button
                Accessible.name: "Search"
                Shape {
                    x: 4.5
                    y: 4.5
                    width: 13
                    height: 13
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: panel.quiet
                        strokeWidth: 1.5
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathSvg { path: "M1.8 5.8a4 4 0 1 0 8 0a4 4 0 1 0-8 0M8.8 8.8L11.6 11.6" }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !panel.searching
                    onClicked: {
                        panel.searching = true;
                        asked.forceActiveFocus();
                    }
                }
                TextInput {
                    Keys.onShortcutOverride: (event) => event.accepted = panel.claims(event)
                    id: asked
                    visible: panel.searching
                    x: 22
                    width: parent.width - 30
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    color: panel.ink
                    selectionColor: Theme.accent.highlight
                    selectedTextColor: panel.ink
                    renderType: Text.NativeRendering
                    selectByMouse: true
                    clip: true
                    onTextChanged: panel.wanted = text
                    Keys.onEscapePressed: {
                        text = "";
                        panel.searching = false;
                        keys.forceActiveFocus();
                        Qt.callLater(panel.reveal);
                    }
                    onActiveFocusChanged: {
                        if (!activeFocus && text === "")
                            panel.searching = false;
                    }
                }
            }
        }

        // The family's typefaces.
        ListView {
            id: styles
            x: 235
            y: 38
            width: parent.width - x
            height: parent.height - y
            topMargin: 10
            bottomMargin: 10
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: panel.faces
            Accessible.role: Accessible.List
            Accessible.name: "Typefaces"
            delegate: Item {
                id: faceRow
                required property string modelData
                readonly property bool chosen: modelData === panel.face
                width: styles.width
                height: 30
                Accessible.role: Accessible.ListItem
                Accessible.name: modelData
                Rectangle {
                    visible: faceRow.chosen
                    x: 10.5
                    width: parent.width - 10.5 - 27.5
                    height: parent.height
                    radius: 8
                    color: panel.chosenFace
                }
                Text {
                    x: 21
                    width: parent.width - 21 - 34
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: faceRow.modelData
                    font.family: panel.family
                    font.styleName: faceRow.modelData
                    font.pixelSize: 13
                    color: panel.ink
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: panel.chooseFace(faceRow.modelData)
                }
            }
        }
    }
}
