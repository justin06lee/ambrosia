import QtCore
import QtQuick
import QtQuick.Window
import QtQuick.Shapes
import Ambrosia

// The Save panel an app of ours shows (Saving.qml shows it), measured from
// macOS 27's small Save sheet in Dark (2026-11-28, raised behind everything
// by a program of our own): 370 wide with corners of 16, over the middle
// of the window it belongs to. Save As and Where 26 tall from 99 to 331,
// 19 and 55 down, their names in the quiet color ending at 93; Cancel and
// Save 79 by 26, 8 apart, 19 from the right and from the foot. With
// nothing of the app's own the buttons come 19 under Where (145 tall); an
// app's pop-ups (a file format) stand between two rules, the first 18
// under Where, the buttons 21 under the second. A Mac's has a Tags field
// between the two rows, which nothing here is behind; its arrow button
// opens the sheet out into the whole browser, which here is Files' own
// panel (Saving.browse): what is chosen there is the answer.
//
// `job` is what is saved (Saving.qml says what it holds). A name already
// taken is asked about on the panel itself. The panel is made anew each
// time and is gone when it closes.
Window {
    id: panel

    property var job: null

    readonly property bool dark: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark
    readonly property QtObject colors: dark ? Theme.darkColors : Theme.lightColors
    // The Print panel's colors (the Mac's with the warmth of what showed
    // through taken out; the light ones are ours).
    readonly property color ground: dark ? "#262524" : "#ececec"
    readonly property color rule: dark ? "#3f3e3c" : "#d6d6d6"
    readonly property color field: dark ? "#191918" : "#ffffff"
    readonly property color fieldRim: dark ? "#363433" : "#c8c8c8"
    readonly property color push: dark ? "#363533" : "#ffffff"
    readonly property color ink: colors.label.primary
    readonly property color quiet: dark ? "#9d9b9a" : "#6a6a6a"

    // Where this app last saved (one file for every app, a part each).
    Settings {
        id: kept
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/ambrosia/save.conf"
        category: Qt.application.name
        property string folder: ""
    }

    property string folder: ""
    property var places: []
    // Each row's choice, by its key.
    property var values: ({})
    readonly property var rows: job?.rows ?? []
    // Asking about a name already taken: the path, or "".
    property string taken: ""
    property bool takenFolder: false
    property bool done: false

    readonly property string extension: {
        const given = job?.extension ?? "";
        return typeof given === "function" ? given(values) : given;
    }
    // The file's name from what was typed: no slashes, the extension added
    // unless it ends in it already.
    function fileName() {
        const typed = input.text.trim().replace(/\//g, ":");
        if (typed === "" || typed === "." || typed === "..")
            return "";
        return extension !== "" && !typed.toLowerCase().endsWith(extension.toLowerCase()) ? typed + extension : typed;
    }
    readonly property bool able: input.text.trim() !== "" && folder !== ""

    function present() {
        places = Places.list();
        const wanted = job.folder ?? "";
        folder = wanted !== "" && Places.isFolder(wanted) ? wanted
               : kept.folder !== "" && Places.isFolder(kept.folder) ? kept.folder : Places.documents();
        const chosen = {};
        for (const row of rows)
            chosen[row.key] = row.current;
        values = chosen;
        input.text = job.name ?? "Untitled";
        input.forceActiveFocus();
        input.selectAll();
    }
    function choose(key, value) {
        const chosen = Object.assign({}, values);
        chosen[key] = value;
        values = chosen;
    }
    function accept() {
        if (taken !== "") {
            if (takenFolder)
                cancel();
            else
                finish(taken);
            return;
        }
        if (!able)
            return;
        const name = fileName();
        if (name === "")
            return;
        const path = (folder === "/" ? "" : folder) + "/" + name;
        if (Places.exists(path)) {
            takenFolder = Places.isFolder(path);
            taken = path;
            alertKeys.forceActiveFocus();
            return;
        }
        finish(path);
    }
    function finish(path) {
        done = true;
        kept.folder = folder;
        const then = job.save, chosen = values;
        close();
        then(path, chosen);
    }
    function cancel() {
        if (taken !== "") {
            taken = "";
            input.forceActiveFocus();
            return;
        }
        close();
    }
    // Any other folder: Files' panel takes over, and the small one goes.
    function browse() {
        done = true;
        const name = fileName() || ((job.name ?? "Untitled") + extension);
        const from = folder, held = job, chosen = values;
        close();
        Saving.browse(held, from, name, chosen);
    }

    title: "Save"
    flags: Qt.Dialog | Qt.FramelessWindowHint
    modality: Qt.WindowModal
    readonly property int formTop: 99
    readonly property int rowsHeight: rows.length === 0 ? 0 : 13 + rows.length * 32 - 6 + 12
    readonly property int tall: taken !== "" ? Math.max(145, Math.ceil(19 + alert.height + 19 + 26 + 19))
                              : rows.length === 0 ? 145 : formTop + 1 + rowsHeight + 1 + 21 + 26 + 19
    readonly property int wide: 370
    width: wide
    height: tall
    minimumWidth: wide
    maximumWidth: wide
    minimumHeight: tall
    maximumHeight: tall
    color: "transparent"

    property bool shaded: false
    onVisibleChanged: {
        if (visible && !shaded) {
            shaded = true;
            Places.shade(panel, 16);
        }
        // Closed by anything but Save: nothing was chosen.
        if (!visible && !done && job && job.cancel)
            job.cancel();
    }

    // ⌘W is the document's Close, and the panel belongs to its window: it
    // is claimed here before shortcuts are looked at (as PrintPanel.qml),
    // and does nothing, as on a Mac with a sheet up. ⌘D is the Desktop, as
    // in a Mac's panel; ⌘. cancels.
    function claims(event) {
        return (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier)) && !(event.modifiers & (Qt.ShiftModifier | Qt.AltModifier))
            && (event.key === Qt.Key_W || event.key === Qt.Key_S || event.key === Qt.Key_D || event.key === Qt.Key_Period);
    }
    function typed(event) {
        if (claims(event)) {
            if (event.key === Qt.Key_Period)
                cancel();
            else if (event.key === Qt.Key_D && taken === "" && Places.desktop() !== "")
                folder = Places.desktop();
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            cancel();
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            accept();
            event.accepted = true;
        }
    }

    component Words: Text {
        color: panel.ink
        font.family: Theme.uiFont
        font.pixelSize: 13
        renderType: Text.NativeRendering
    }

    // A push button, 26 tall; the one Return presses takes the accent
    // color while the panel is in front.
    component Push: Rectangle {
        id: button
        property string text
        property bool primary: false
        signal pressed()

        width: 79
        height: 26
        radius: 7
        readonly property bool lit: primary && enabled && panel.active
        color: lit ? Theme.accent.bg : panel.push
        border.width: panel.dark || lit ? 0 : 0.5
        border.color: panel.fieldRim
        Accessible.role: Accessible.Button
        Accessible.name: text
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
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

    Rectangle {
        id: body
        anchors.fill: parent
        radius: 16
        color: panel.ground
        border.width: 0.5
        border.color: panel.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.14)

        // The panel moves with its window; a drag on it does nothing.
        FocusScope {
            id: form
            visible: panel.taken === ""
            anchors.fill: parent
            focus: true
            Keys.onShortcutOverride: (event) => event.accepted = panel.claims(event)
            Keys.onPressed: (event) => panel.typed(event)

            Words { x: 93 - implicitWidth; y: 19 + (26 - height) / 2; text: "Save As:"; color: panel.quiet }
            Rectangle {
                x: 99
                y: 19
                width: 232
                height: 26
                radius: 6
                color: panel.field
                border.width: input.activeFocus && panel.active ? 2.5 : 0.5
                border.color: input.activeFocus && panel.active ? Theme.accent.bg : panel.fieldRim
                TextInput {
                    id: input
                    x: 7
                    width: parent.width - 14
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    focus: true
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    color: panel.ink
                    selectionColor: Theme.accent.highlight
                    selectedTextColor: panel.ink
                    renderType: Text.NativeRendering
                    selectByMouse: true
                    Accessible.role: Accessible.EditableText
                    Accessible.name: "Save As"
                    Keys.onShortcutOverride: (event) => event.accepted = panel.claims(event)
                    Keys.onPressed: (event) => panel.typed(event)
                }
            }
            Words { x: 93 - implicitWidth; y: 55 + (26 - height) / 2; text: "Where:"; color: panel.quiet }
            PrefPopup {
                id: where
                x: 99
                y: 55
                width: 200
                height: 26
                // Tab stays in the field, as on a Mac.
                activeFocusOnTab: false
                // Where it goes, the places at hand, and any other.
                items: (panel.places.some(place => place.path === panel.folder) || panel.folder === "" ? []
                            : [{ text: Places.name(panel.folder), value: panel.folder }, { text: "" }])
                    .concat(panel.places.map(place => ({ text: place.name, value: place.path })))
                    .concat([{ text: "" }, { text: "Other…", value: "other:" }])
                current: panel.folder
                onChosen: (value) => value === "other:" ? panel.browse() : panel.folder = value
            }
            // The whole browser.
            Rectangle {
                x: 305
                y: 55
                width: 26
                height: 26
                radius: 6
                color: where.color
                Accessible.role: Accessible.Button
                Accessible.name: "Show more options"
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    visible: more.pressed
                    color: panel.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08)
                }
                Shape {
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: panel.ink
                        strokeWidth: 1.6
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathSvg { path: "M2.4 4.3L6 7.9l3.6-3.6" }
                    }
                }
                MouseArea { id: more; anchors.fill: parent; onClicked: panel.browse() }
            }

            // The app's own: pop-ups between two rules, their names and
            // themselves together in the middle.
            Rectangle { visible: panel.rows.length > 0; y: panel.formTop; width: parent.width; height: 1; color: panel.rule }
            Repeater {
                id: own
                model: panel.rows.length
                Item {
                    id: line
                    required property int index
                    readonly property var row: panel.rows[index]
                    readonly property real across: name.implicitWidth + 6 + choice.width
                    x: Math.round((form.width - across) / 2)
                    y: panel.formTop + 1 + 13 + index * 32
                    width: across
                    height: 26
                    Words { id: name; anchors.verticalCenter: parent.verticalCenter; text: line.row.label }
                    PrefPopup {
                        id: choice
                        x: name.implicitWidth + 6
                        height: 26
                        width: Math.max(150, Math.min(250, implicitWidth + 16))
                        activeFocusOnTab: false
                        items: line.row.items
                        current: panel.values[line.row.key]
                        onChosen: (value) => panel.choose(line.row.key, value)
                    }
                }
            }
            Rectangle { visible: panel.rows.length > 0; y: panel.formTop + 1 + panel.rowsHeight; width: parent.width; height: 1; color: panel.rule }

            Push {
                x: 370 - 19 - 79 - 8 - 79
                y: panel.tall - 19 - 26
                text: "Cancel"
                onPressed: panel.cancel()
            }
            Push {
                x: 370 - 19 - 79
                y: panel.tall - 19 - 26
                text: "Save"
                primary: true
                enabled: panel.able
                onPressed: panel.accept()
            }
        }

        // A name already taken: asked about here, in the panel's own
        // width (a Mac raises an alert over its sheet), the buttons where
        // the panel's are.
        FocusScope {
            id: alertKeys
            visible: panel.taken !== ""
            anchors.fill: parent
            Keys.onShortcutOverride: (event) => event.accepted = panel.claims(event)
            Keys.onPressed: (event) => panel.typed(event)
            Column {
                id: alert
                x: 20
                y: 19
                width: 370 - 40
                spacing: 6
                Words {
                    width: parent.width
                    wrapMode: Text.Wrap
                    font.weight: 700
                    text: panel.takenFolder ? "“" + panel.taken.replace(/^.*\//, "") + "” is a folder and can’t be replaced."
                                            : "“" + panel.taken.replace(/^.*\//, "") + "” already exists. Do you want to replace it?"
                }
                Words {
                    width: parent.width
                    wrapMode: Text.Wrap
                    font.pixelSize: 11
                    text: panel.takenFolder ? "Choose another name."
                        : "A file or folder with the same name already exists in the folder " + Places.name(panel.folder) + ". Replacing it will overwrite its current contents."
                }
            }
            Push {
                visible: !panel.takenFolder
                x: 370 - 19 - 79 - 8 - 79
                y: panel.tall - 19 - 26
                text: "Cancel"
                onPressed: panel.cancel()
            }
            Push {
                x: 370 - 19 - 79
                y: panel.tall - 19 - 26
                text: panel.takenFolder ? "OK" : "Replace"
                primary: true
                onPressed: panel.accept()
            }
        }
    }
}
