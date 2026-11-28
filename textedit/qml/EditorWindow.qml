import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Effects
import QtQuick.Window
import Ambrosia
import TextEditor
import "rtf.mjs" as Rtf

// A TextEdit window, measured from macOS 27's (Look.qml): the title bar
// with the lights, the document's icon and name; for rich text the format
// bar and the ruler under it; then the text. Plain text is a .txt in the
// fixed-width font, rich text an .rtf (rtf.mjs reads and writes it).
// Frameless: it draws its own corners and lights (KWin draws the shadow;
// App.decorate asks for it) and is moved by its title bar and resized by
// its edges.
Window {
    id: win

    // Main.qml, which made it.
    required property var app
    // The document's file, as a URL; none while it is untitled.
    property string file: ""
    // A file to open as the window is made.
    property string opening: ""
    // The name its place and size are kept under (Main.qml gives it, from
    // the document opened; a new document has none and opens where KWin
    // puts it).
    property string frameName: ""
    property bool rich: true
    property string untitledName: "Untitled"
    readonly property string name: file !== "" ? App.name(file) : untitledName
    readonly property bool edited: hands.modified
    // Nothing typed and no file: the first document opened takes its place.
    readonly property bool pristine: file === "" && opening === "" && !edited && hands.empty
    readonly property var edit: holder.item
    readonly property Editor editor: hands
    property bool finding: false
    // What the text will be once its TextEdit is made: { model } or
    // { text }, and whether it counts as changed already.
    property var content: null

    // A window keeps its active look while one of its menus is open, as on
    // a Mac; --active draws it active for grabs.
    property int menusOpen: 0
    // Something of Ambrosia's own is open over the screen (the app menu,
    // the control center): its menu bar says so through the menu named for
    // the app (MenuBar.qml). Yes or no, not a count: a missed word from
    // the bar must not leave the window lit for good.
    property bool shellOpen: false
    readonly property bool looksActive: active || menusOpen > 0 || shellOpen || App.active
    readonly property bool maximized: visibility === Window.Maximized || visibility === Window.FullScreen
    readonly property int corner: maximized ? 0 : Look.windowRadius
    onActiveChanged: {
        if (active) {
            menusOpen = 0;
            tellPanels();
        }
    }

    readonly property real ratio: Screen.devicePixelRatio
    readonly property real titleBar: Look.snap(Look.titleBar, ratio)
    readonly property real formatBar: Look.snap(Look.formatBar, ratio)
    readonly property real rulerEnd: Look.snap(Look.ruler, ratio)

    // A key that is also a menu item's shortcut is handed to one of the two
    // in turn, the window's own marked ambiguous: either way it runs, once.
    property var lastAct: ({ name: "", at: 0 })
    function act(name, run) {
        const now = Date.now();
        if (lastAct.name === name && now - lastAct.at < 150)
            return;
        lastAct = { name: name, at: now };
        run();
    }
    function takeKeys() {
        if (alert.visible)
            return;
        if (edit)
            edit.forceActiveFocus();
    }
    function toggleZoom() {
        maximized ? showNormal() : showMaximized();
    }

    // The format keys and menu items; the format bar's controls go to the
    // Editor themselves.
    function format(what) {
        if (!rich)
            return;
        switch (what) {
        case "bold": hands.setBold(!hands.bold); break;
        case "italic": hands.setItalic(!hands.italic); break;
        case "underline": hands.setUnderline(!hands.underline); break;
        case "bigger": hands.bigger(1); break;
        case "smaller": hands.bigger(-1); break;
        default: hands.setAlignment(what);
        }
    }

    // The Fonts and Colors panels (the kit's), for the selection: each
    // choice made there goes to the Editor, and the panels show what the
    // selection has as it moves.
    function fontNow() {
        return { family: App.family(hands.family), weight: hands.weight, italic: hands.italic, size: hands.size };
    }
    function applyFont(family, weight, italic, size, what) {
        if (!rich)
            return;
        if (what === "size") {
            hands.setSize(size);
        } else {
            if (what === "family")
                hands.setFamily(family);
            hands.setStyle(weight, italic);
        }
    }
    function colorNow() {
        return hands.color.valid ? hands.color : Look.text;
    }
    function applyColor(color) {
        if (rich)
            hands.setColor(hands.storedName(color));
    }
    function showFonts() {
        if (rich)
            Fonts.show(App, fontNow(), applyFont, win);
    }
    function showColors() {
        if (rich)
            Colors.show(colorNow(), applyColor, win);
    }
    // (Not while a choice from a panel is on its way in: the panel knows.)
    function tellPanels() {
        if (!rich || !active)
            return;
        if (Fonts.shown)
            Fonts.follow(fontNow(), applyFont);
        if (Colors.shown)
            Colors.follow(colorNow(), applyColor);
    }

    // Reads a file into `content`; what went wrong, or nothing.
    function load(target) {
        const got = App.read(target, Prefs.openEncoding);
        if (!got.ok)
            return got.error;
        // TextEdit's Settings: an RTF file shown as its code is plain text.
        if (got.rtf && !Prefs.rtfAsCode) {
            const model = Rtf.parse(got.text, (page, bytes) => App.decode(page, String.fromCharCode.apply(null, bytes)) || null);
            const families = {};
            for (const paragraph of model.paragraphs) {
                for (const run of paragraph.runs) {
                    run.family = families[run.family] ?? (families[run.family] = App.family(run.family));
                    // Black is the text's own color: white in Dark, as
                    // a Mac's TextEdit shows it.
                    if (run.color === "#000000")
                        run.color = "";
                }
            }
            rich = true;
            content = { model: model };
            if (model.view) {
                width = Math.max(Look.richMinWidth, Math.min(Screen.width - 40, Math.round(model.view.width) + Look.viewAside));
                height = Math.max(Look.minHeight, Math.min(Screen.height - 140, Math.round(model.view.height) + Look.viewAbove));
            }
        } else {
            rich = false;
            content = { text: got.text };
            sizeAsNew();
        }
        file = target;
        return "";
    }
    // The TextEdit is made (anew when the document changes between plain
    // and rich): what it is to hold goes in.
    function fill() {
        if (!edit)
            return;
        const now = content;
        content = null;
        if (now?.model)
            hands.setModel(now.model);
        else if (now && now.text !== undefined)
            hands.setText(now.text);
        else if (rich)
            hands.startRich();
        else
            hands.setText("");
        if (now?.edited)
            hands.modified = true;
        edit.cursorPosition = 0;
        takeKeys();
    }

    // Saves, asking where first when it has no file (the Save panel over
    // this window, kit/Saving.qml: a rich document's format, a plain one's
    // encoding, as a Mac's TextEdit adds to its panel); `then` once saved.
    function save(then) {
        if (file === "") {
            Saving.show({
                name: name,
                extension: rich ? ".rtf" : Prefs.addTxt ? ".txt" : "",
                filter: rich ? "Rich Text Document (*.rtf)" : "Plain Text (*.txt)",
                rows: rich ? [{ key: "format", label: "File Format:", items: [{ text: "Rich Text Document", value: "rtf" }], current: "rtf" }]
                           : [{ key: "encoding", label: "Plain Text Encoding:", current: Prefs.saveEncoding, items: [
                                 { text: "Automatic", value: "auto" }, {},
                                 { text: "Unicode (UTF-8)", value: "utf-8" }, { text: "Unicode (UTF-16)", value: "utf-16" }, { text: "Western (ISO Latin 1)", value: "latin1" }] }],
                save: (path, values) => {
                    if (win.write(String(Places.url(path)), values.encoding) && then)
                        then();
                },
            }, win);
            return;
        }
        if (write(file) && then)
            then();
    }
    function write(target, encoding) {
        let failure;
        if (rich) {
            const model = hands.model();
            model.view = { width: win.width - Look.viewAside, height: win.height - Look.viewAbove };
            failure = App.write(target, Rtf.write(model), true);
        } else {
            failure = App.write(target, hands.text(), false, encoding ?? Prefs.saveEncoding);
        }
        if (failure !== "") {
            alert.ask("The document “" + name + "” could not be saved.", failure, [{ text: "OK", role: "ok", primary: true, cancel: true }], null);
            return false;
        }
        file = target;
        hands.modified = false;
        return true;
    }
    function exportPdf() {
        Saving.show({
            name: name.replace(/\.[^.]+$/, ""),
            extension: ".pdf",
            filter: "PDF (*.pdf)",
            save: (path) => hands.exportPdf(Places.url(path), win.name),
        }, win);
    }
    // The Print panel, over this window (kit/Printing.qml): the document
    // as a PDF made for the paper chosen there.
    function printOut() {
        Printing.show({
            title: name.replace(/\.[^.]+$/, ""),
            make: (file, size) => hands.exportPdf(file, win.name, size),
            save: () => win.exportPdf(),
        }, win);
    }

    // Closing a document with changes asks first; `then` once it is gone.
    property bool closingForSure: false
    onClosing: (close) => {
        if (edited && !closingForSure) {
            close.accepted = false;
            askClose(null);
            return;
        }
        app.closed(win);
    }
    function askClose(then) {
        const fresh = file === "";
        alert.ask(fresh ? "Do you want to keep this new document “" + name + "”?"
                        : "Do you want to save the changes made to the document “" + name + "”?",
                  fresh ? "You can choose to save your changes, or delete this document immediately. You can’t undo this action."
                        : "Your changes will be lost if you don’t save them.",
                  [{ text: fresh ? "Save…" : "Save", role: "save", primary: true },
                   { text: fresh ? "Delete" : "Revert Changes", role: "discard", discard: true },
                   { text: "Cancel", role: "cancel", cancel: true }],
                  (role) => {
                      if (role === "save")
                          win.save(() => win.finish(then));
                      else if (role === "discard")
                          win.finish(then);
                  });
    }
    function finish(then) {
        closingForSure = true;
        close();
        if (then)
            then();
    }

    // Format > Make Plain Text and Make Rich Text. The document is then a
    // new one of the other kind, to be saved under a name again.
    function toggleRich() {
        const had = !hands.empty || file !== "";
        const turn = (to) => {
            if (file !== "") {
                untitledName = name.replace(/\.[^.]+$/, "");
                file = "";
            }
            to.edited = had;
            content = to;
            if (!rich && width < Look.richMinWidth)
                width = Look.richMinWidth;
            rich = !rich;
        };
        if (rich) {
            const plain = () => turn({ text: hands.text() });
            if (hands.empty)
                plain();
            else
                alert.ask("Convert this document to plain text?",
                          "Making a document plain text will remove all text styles and document properties.",
                          [{ text: "OK", role: "ok", primary: true }, { text: "Cancel", role: "cancel", cancel: true }],
                          (role) => { if (role === "ok") plain(); });
        } else {
            const tabs = Array.from({ length: 12 }, (_, i) => 28 * (i + 1));
            turn({ model: { paragraphs: hands.text().split("\n").map(line => ({
                align: "left", left: 0, first: 0, right: 0, before: 0, after: 0, spacing: 1, tabs: tabs, list: null,
                runs: [{ text: line, family: Prefs.richFamily, size: Prefs.richSize, bold: false, italic: false, underline: false, strike: false,
                         color: "", background: "", script: "" }],
            })) } });
        }
    }

    function find() {
        finding = true;
        findBar.focusField();
    }
    function show(found) {
        if (found.start === undefined)
            return false;
        edit.select(found.start, found.end);
        reveal();
        return true;
    }
    function findNext(direction) {
        if (findBar.text === "") {
            find();
            return;
        }
        show(hands.find(findBar.text, direction < 0 ? edit.selectionStart : edit.selectionEnd, direction < 0));
    }
    function endFind() {
        finding = false;
        takeKeys();
    }
    // The cursor (or what was found) scrolled into sight.
    function reveal() {
        if (!edit)
            return;
        const at = edit.cursorRectangle;
        if (at.y < flick.contentY)
            flick.contentY = Math.max(0, at.y - 4);
        else if (at.y + at.height > flick.contentY + flick.height)
            flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), at.y + at.height - flick.height + 4);
    }

    // A new document's window is as wide and tall as TextEdit's Settings
    // say (Prefs.windowSize), within the screen.
    function sizeAsNew() {
        const size = Prefs.windowSize(rich);
        width = Math.max(rich ? Look.richMinWidth : Look.minWidth, Math.min(Screen.width - 40, size.width));
        height = Math.max(Look.minHeight, Math.min(Screen.height - 140, size.height));
    }
    width: Look.richWidth
    height: Look.richHeight
    minimumWidth: rich ? Look.richMinWidth : Look.minWidth
    minimumHeight: Look.minHeight
    visible: false
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: name

    readonly property Appearance appearance: Appearance {}
    MenuBar { doc: win }
    Editor {
        id: hands
        document: win.edit ? win.edit.textDocument : null
        dark: Look.dark
        cursorPosition: win.edit?.cursorPosition ?? 0
        selectionStart: win.edit?.selectionStart ?? 0
        selectionEnd: win.edit?.selectionEnd ?? 0
        onFormatChanged: win.tellPanels()
    }

    Component.onCompleted: {
        let failure = "";
        if (opening !== "") {
            failure = load(opening);
            if (failure !== "")
                untitledName = App.name(opening);
            opening = "";
        } else {
            sizeAsNew();
        }
        holder.active = true;
        visible = true;
        if (failure !== "") {
            alert.ask("The document “" + untitledName + "” could not be opened.", failure,
                      [{ text: "OK", role: "ok", primary: true, cancel: true }], () => win.finish(null));
        } else if (App.find !== "") {
            findBar.text = App.find;
            finding = true;
        }
    }
    onVisibleChanged: {
        if (visible) {
            App.decorate(win, Look.windowRadius);
            Qt.callLater(App.shown, win);
        }
    }

    Shortcut { sequences: ["Ctrl+N", "Meta+N"]; onActivated: win.act("new", () => win.app.newDocument()); onActivatedAmbiguously: win.act("new", () => win.app.newDocument()) }
    Shortcut { sequences: ["Ctrl+O", "Meta+O"]; onActivated: win.act("open", () => App.chooseFiles()); onActivatedAmbiguously: win.act("open", () => App.chooseFiles()) }
    Shortcut { sequences: ["Ctrl+W", "Meta+W"]; onActivated: win.act("close", win.close); onActivatedAmbiguously: win.act("close", win.close) }
    Shortcut { sequences: ["Ctrl+,", "Meta+,"]; onActivated: win.act("settings", () => Preferences.show("TextEditor", "SettingsWindow")); onActivatedAmbiguously: win.act("settings", () => Preferences.show("TextEditor", "SettingsWindow")) }
    Shortcut { sequences: ["Ctrl+S", "Meta+S"]; onActivated: win.act("save", () => win.save(null)); onActivatedAmbiguously: win.act("save", () => win.save(null)) }
    Shortcut { sequences: ["Ctrl+P", "Meta+P"]; onActivated: win.act("print", win.printOut); onActivatedAmbiguously: win.act("print", win.printOut) }
    Shortcut { sequences: ["Ctrl+M", "Meta+M"]; onActivated: win.act("minimize", win.showMinimized); onActivatedAmbiguously: win.act("minimize", win.showMinimized) }
    Shortcut { sequences: ["Ctrl+Q", "Meta+Q"]; onActivated: win.act("quit", win.app.quit); onActivatedAmbiguously: win.act("quit", win.app.quit) }
    Shortcut { sequences: ["Ctrl+T", "Meta+T"]; enabled: win.rich; onActivated: win.act("fonts", win.showFonts); onActivatedAmbiguously: win.act("fonts", win.showFonts) }
    Shortcut { sequences: ["Ctrl+Shift+C", "Meta+Shift+C"]; enabled: win.rich; onActivated: win.act("colors", win.showColors); onActivatedAmbiguously: win.act("colors", win.showColors) }
    Shortcut { sequences: ["Ctrl+F", "Meta+F"]; onActivated: win.act("find", win.find); onActivatedAmbiguously: win.act("find", win.find) }
    Shortcut { sequences: ["Ctrl+G", "Meta+G"]; onActivated: win.act("findNext", () => win.findNext(1)); onActivatedAmbiguously: win.act("findNext", () => win.findNext(1)) }
    Shortcut { sequences: ["Ctrl+Shift+G", "Meta+Shift+G"]; onActivated: win.act("findPrevious", () => win.findNext(-1)); onActivatedAmbiguously: win.act("findPrevious", () => win.findNext(-1)) }
    Shortcut { sequences: ["Ctrl+B", "Meta+B"]; enabled: win.rich; onActivated: win.act("bold", () => win.format("bold")); onActivatedAmbiguously: win.act("bold", () => win.format("bold")) }
    Shortcut { sequences: ["Ctrl+I", "Meta+I"]; enabled: win.rich; onActivated: win.act("italic", () => win.format("italic")); onActivatedAmbiguously: win.act("italic", () => win.format("italic")) }
    Shortcut { sequences: ["Ctrl+U", "Meta+U"]; enabled: win.rich; onActivated: win.act("underline", () => win.format("underline")); onActivatedAmbiguously: win.act("underline", () => win.format("underline")) }
    Shortcut { sequences: ["Ctrl++", "Ctrl+=", "Meta++", "Meta+="]; enabled: win.rich; onActivated: win.act("bigger", () => win.format("bigger")); onActivatedAmbiguously: win.act("bigger", () => win.format("bigger")) }
    Shortcut { sequences: ["Ctrl+-", "Meta+-"]; enabled: win.rich; onActivated: win.act("smaller", () => win.format("smaller")); onActivatedAmbiguously: win.act("smaller", () => win.format("smaller")) }
    Shortcut { sequences: ["Ctrl+{", "Meta+{"]; enabled: win.rich; onActivated: win.act("left", () => win.format("left")); onActivatedAmbiguously: win.act("left", () => win.format("left")) }
    Shortcut { sequences: ["Ctrl+|", "Meta+|"]; enabled: win.rich; onActivated: win.act("center", () => win.format("center")); onActivatedAmbiguously: win.act("center", () => win.format("center")) }
    Shortcut { sequences: ["Ctrl+}", "Meta+}"]; enabled: win.rich; onActivated: win.act("right", () => win.format("right")); onActivatedAmbiguously: win.act("right", () => win.format("right")) }
    Shortcut { sequences: ["Ctrl+Shift+T", "Meta+Shift+T"]; onActivated: win.act("toggleRich", win.toggleRich); onActivatedAmbiguously: win.act("toggleRich", win.toggleRich) }

    Component {
        id: richEdit
        TextEdit {
            textFormat: TextEdit.RichText
            font.family: Prefs.richFamily
            font.pointSize: Prefs.richSize
            leftPadding: Look.richInset
            rightPadding: Look.richInset
            Keys.onPressed: (event) => {
                // A list's keys: Return in an empty item ends the list,
                // Tab and Shift-Tab move an item a level.
                const bare = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier));
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && bare && !(event.modifiers & Qt.ShiftModifier))
                    event.accepted = hands.returnInList();
                else if (event.key === Qt.Key_Tab && bare)
                    event.accepted = hands.indentList(1);
                else if (event.key === Qt.Key_Backtab && bare)
                    event.accepted = hands.indentList(-1);
            }
        }
    }
    Component {
        id: plainEdit
        TextEdit {
            textFormat: TextEdit.PlainText
            font.family: Prefs.plainFont
            font.pointSize: Prefs.plainSize
            leftPadding: Look.plainInset
            rightPadding: Look.plainInset
        }
    }

    Item {
        id: frame
        anchors.fill: parent

        // Under the bars: the ruler, the Find bar and the text, cut to the
        // window's bottom corners.
        Item {
            id: body
            y: win.rich ? win.formatBar : win.titleBar
            width: parent.width
            height: parent.height - y
            // (The off-screen renderer draws no masks: a grab goes without.)
            layer.enabled: !win.maximized && Qt.platform.pluginName !== "offscreen"
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: bodyShape
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Rectangle { anchors.fill: parent; color: Look.page }

            Ruler {
                id: ruler
                visible: win.rich
                width: parent.width
                height: win.rich && Prefs.ruler ? win.rulerEnd - win.formatBar : 0
                window: win
                textWidth: flick.width - 2 * Look.richInset
            }
            FindBar {
                id: findBar
                visible: win.finding
                y: ruler.height
                width: parent.width
                window: win
                onNext: (direction) => win.findNext(direction)
                onDone: win.endFind()
                onTextChanged: looking.restart()
                onReplaceOne: {
                    const chosen = win.edit.selectedText;
                    if (chosen !== "" && chosen.toLowerCase() === text.toLowerCase())
                        hands.replace(win.edit.selectionStart, win.edit.selectionEnd, replacement);
                    win.findNext(1);
                    matches = hands.count(text);
                }
                onReplaceEvery: {
                    hands.replaceAll(text, replacement);
                    matches = hands.count(text);
                }
            }
            // What's typed in the Find bar is looked for a moment after the
            // typing stops, from where the selection begins.
            Timer {
                id: looking
                interval: 150
                onTriggered: {
                    findBar.matches = findBar.text === "" ? -1 : hands.count(findBar.text);
                    if (findBar.matches > 0)
                        win.show(hands.find(findBar.text, win.edit.selectionStart, false));
                }
            }

            Flickable {
                id: flick
                y: ruler.height + (win.finding ? findBar.height : 0)
                width: parent.width
                height: parent.height - y
                contentWidth: width
                contentHeight: holder.item ? holder.item.height : height
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                Controls.ScrollBar.vertical: ScrollThumb {}

                Loader {
                    id: holder
                    active: false
                    sourceComponent: win.rich ? richEdit : plainEdit
                    onLoaded: {
                        item.width = Qt.binding(() => flick.width);
                        item.height = Qt.binding(() => Math.max(item.implicitHeight, flick.height));
                        item.wrapMode = TextEdit.Wrap;
                        item.tabStopDistance = 28;
                        item.bottomPadding = 6;
                        item.color = Qt.binding(() => Look.text);
                        item.selectionColor = Qt.binding(() => win.looksActive ? Look.selection : Look.selectionInactive);
                        item.selectedTextColor = Qt.binding(() => Look.text);
                        item.selectByMouse = true;
                        item.persistentSelection = true;
                        item.cursorDelegate = caret;
                        item.cursorRectangleChanged.connect(win.reveal);
                        win.fill();
                    }
                }
                // Right-click: the usual three.
                MouseArea {
                    anchors.fill: holder
                    acceptedButtons: Qt.RightButton
                    cursorShape: Qt.IBeamCursor
                    onClicked: (mouse) => {
                        win.takeKeys();
                        context.openAt(flick.contentItem, mouse.x, mouse.y);
                    }
                }
            }
            // The insertion point: the accent color, two wide, as macOS
            // draws it since 14.
            Component {
                id: caret
                Rectangle {
                    id: point
                    width: 2
                    radius: 1
                    color: Theme.accent.bg
                    visible: win.edit && win.edit.activeFocus && win.edit.selectionStart === win.edit.selectionEnd
                    SequentialAnimation on opacity {
                        running: point.visible
                        loops: Animation.Infinite
                        PauseAnimation { duration: 500 }
                        NumberAnimation { to: 0; duration: 120 }
                        PauseAnimation { duration: 380 }
                        NumberAnimation { to: 1; duration: 120 }
                    }
                }
            }
            PopupMenu {
                id: context
                items: [
                    { text: "Cut", value: "cut", enabled: (win.edit?.selectedText ?? "") !== "" },
                    { text: "Copy", value: "copy", enabled: (win.edit?.selectedText ?? "") !== "" },
                    { text: "Paste", value: "paste", enabled: win.edit?.canPaste ?? false },
                ]
                onChosen: (what) => {
                    if (what === "cut")
                        win.edit.cut();
                    else if (what === "copy")
                        win.edit.copy();
                    else
                        win.edit.paste();
                    win.takeKeys();
                }
            }
        }
        Item {
            id: bodyShape
            width: body.width
            height: body.height
            visible: false
            layer.enabled: true
            Rectangle {
                anchors.fill: parent
                bottomLeftRadius: Look.windowRadius
                bottomRightRadius: Look.windowRadius
                color: "black"
            }
        }

        // The title bar's band, which a rich text window's format bar
        // shares.
        Rectangle {
            width: parent.width
            height: body.y
            topLeftRadius: win.corner
            topRightRadius: win.corner
            color: Look.bar

            // The window moves by its title bar; two clicks zoom it.
            DragHandler {
                target: null
                onActiveChanged: if (active) win.startSystemMove()
            }
            TapHandler {
                onTapped: win.takeKeys()
                onDoubleTapped: win.toggleZoom()
            }
        }
        TrafficLights {
            x: Look.lightsX
            y: Look.lightsY
            window: win
        }
        Image {
            id: icon
            visible: win.file !== ""
            x: Look.titleIconX
            y: 8
            width: 16
            height: 16
            sourceSize: Qt.size(32, 32)
            source: win.file !== "" ? "image://icon/" + App.iconName(win.file) : ""
            opacity: win.looksActive ? 1 : 0.5
        }
        Row {
            x: icon.visible ? Look.titleX : Look.titleIconX
            height: 32
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: win.name
                font.weight: 700
                elide: Text.ElideMiddle
                width: Math.min(implicitWidth, win.width - parent.x - 90)
                color: win.looksActive ? Look.title : Look.titleInactive
            }
            Label {
                anchors.verticalCenter: parent.verticalCenter
                visible: win.edited
                text: " — Edited"
                color: win.looksActive ? Look.titleNote : Look.titleInactive
            }
        }
        FormatBar {
            id: formatBar
            visible: win.rich
            width: parent.width
            window: win
        }

        Alert {
            id: alert
            anchors.fill: parent
            window: win
        }

        // The window's rim, over everything.
        Rectangle {
            anchors.fill: parent
            radius: win.corner
            color: "transparent"
            border.width: 0.5
            border.color: Look.rim
        }

        // Resizing by the edges and corners.
        Repeater {
            model: win.maximized ? [] : [
                { edges: Qt.LeftEdge, x: 0, y: 8, w: 5, h: -16, shape: Qt.SizeHorCursor },
                { edges: Qt.RightEdge, x: -5, y: 8, w: 5, h: -16, shape: Qt.SizeHorCursor },
                { edges: Qt.TopEdge, x: 8, y: 0, w: -16, h: 5, shape: Qt.SizeVerCursor },
                { edges: Qt.BottomEdge, x: 8, y: -5, w: -16, h: 5, shape: Qt.SizeVerCursor },
                { edges: Qt.TopEdge | Qt.LeftEdge, x: 0, y: 0, w: 10, h: 10, shape: Qt.SizeFDiagCursor },
                { edges: Qt.TopEdge | Qt.RightEdge, x: -10, y: 0, w: 10, h: 10, shape: Qt.SizeBDiagCursor },
                { edges: Qt.BottomEdge | Qt.LeftEdge, x: 0, y: -10, w: 10, h: 10, shape: Qt.SizeBDiagCursor },
                { edges: Qt.BottomEdge | Qt.RightEdge, x: -10, y: -10, w: 10, h: 10, shape: Qt.SizeFDiagCursor },
            ]
            Item {
                required property var modelData
                x: modelData.x < 0 ? frame.width + modelData.x : modelData.x
                y: modelData.y < 0 ? frame.height + modelData.y : modelData.y
                width: modelData.w < 0 ? frame.width + modelData.w : modelData.w
                height: modelData.h < 0 ? frame.height + modelData.h : modelData.h
                HoverHandler { cursorShape: parent.modelData.shape }
                DragHandler {
                    target: null
                    onActiveChanged: if (active) win.startSystemResize(parent.modelData.edges)
                }
            }
        }
    }
}
