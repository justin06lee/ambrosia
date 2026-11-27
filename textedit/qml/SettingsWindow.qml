import QtQuick
import QtQuick.Window
import Qt.labs.platform as Platform
import Ambrosia
import TextEditor

// TextEdit's Settings, from the TextEdit menu or ⌘,: laid out as macOS
// 27's by measure (Dark, 2026-11-28): 439 wide, a box 22 in from each
// side from 65 down with the two tabs' control astride its top edge, the
// headings in bold with their rows under them, and Restore All Defaults
// under the box. Only what our TextEdit does is here (a Mac's has
// properties, spelling and HTML too), so the box ends sooner; both tabs
// share the taller one's height, as a Mac's share theirs. Each control
// sets Prefs, which every window reads live. A plain window in the
// session's frame; y's below are the Mac's less its 32 bar.
Window {
    id: settings

    readonly property real bar: Theme.size.titlebar.height
    readonly property bool dark: Qt.styleHints.colorScheme === Qt.ColorScheme.Dark
    readonly property QtObject colors: dark ? Theme.darkColors : Theme.lightColors
    readonly property color ink: colors.label.primary
    // The Mac's box is its bar's color on a ground a little darker.
    readonly property color ground: dark ? Qt.darker(colors.bg.window, 1.2) : colors.bg.window
    readonly property color boxFill: dark ? colors.bg.window : Qt.rgba(0, 0, 0, 0.03)
    readonly property color boxEdge: dark ? Qt.rgba(1, 1, 1, 0.065) : Qt.rgba(0, 0, 0, 0.08)
    readonly property color face: dark ? Qt.rgba(1, 1, 1, 0.075) : Qt.rgba(0, 0, 0, 0.06)
    property int tab: 0

    title: "Settings"
    flags: Qt.Window | Qt.CustomizeWindowHint | Qt.WindowTitleHint | Qt.WindowCloseButtonHint | Qt.WindowMinimizeButtonHint
    readonly property real tall: 415 - bar
    width: 439
    height: tall
    minimumWidth: 439
    maximumWidth: 439
    minimumHeight: tall
    maximumHeight: tall
    color: ground

    // Text on a line whose middle is at the Mac's y.
    component Line: Text {
        property real mid
        y: mid - settings.bar - height / 2
        color: settings.ink
        font.family: Theme.uiFont
        font.pixelSize: 13
        renderType: Text.NativeRendering
    }
    component Heading: Line {
        x: 43
        font.weight: Font.Bold
    }
    component Check: PrefCheck {
        property real mid
        x: 50
        y: mid - settings.bar - 7
        box: 14
    }
    // One of a set: a ring, filled in the accent color with a white dot
    // when it is the choice (gray in a window that isn't in front).
    component Radio: Item {
        id: radio
        property real mid
        property bool chosen
        property string text
        signal picked()
        x: 50
        y: mid - settings.bar - 7
        width: 14 + 6 + label.implicitWidth
        height: 14
        Accessible.role: Accessible.RadioButton
        Accessible.name: text
        Accessible.checked: chosen
        Rectangle {
            width: 14
            height: 14
            radius: 7
            color: radio.chosen && settings.active ? Theme.accent.bg
                 : radio.chosen ? (settings.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.16))
                 : settings.dark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.07)
            Rectangle {
                anchors.centerIn: parent
                visible: radio.chosen
                width: 6
                height: 6
                radius: 3
                color: settings.active ? Theme.accent.fg : settings.dark ? "#dddddd" : "#ffffff"
            }
        }
        Text {
            id: label
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            text: radio.text
            color: settings.ink
            font.family: Theme.uiFont
            font.pixelSize: 13
            renderType: Text.NativeRendering
        }
        MouseArea { anchors.fill: parent; onClicked: radio.picked() }
    }
    // A whole number in a dark field; Return, Tab or a click elsewhere
    // takes it, within its limits.
    component NumberField: Rectangle {
        id: field
        property real mid
        property int value
        property int least: 1
        property int most: 999
        signal took(int value)
        x: 90
        y: mid - settings.bar - 11
        width: 47
        height: 22
        radius: 5
        color: settings.dark ? "#191818" : "#ffffff"
        border.width: input.activeFocus ? 2 : settings.dark ? 0 : 0.5
        border.color: input.activeFocus ? Theme.accent.bg : Qt.rgba(0, 0, 0, 0.15)
        TextInput {
            id: input
            anchors.fill: parent
            leftPadding: 7
            rightPadding: 7
            verticalAlignment: TextInput.AlignVCenter
            text: field.value
            color: settings.ink
            selectionColor: Theme.accent.bg
            selectedTextColor: Theme.accent.fg
            font.family: Theme.uiFont
            font.pixelSize: 13
            renderType: Text.NativeRendering
            selectByMouse: true
            validator: IntValidator { bottom: 0; top: 9999 }
            activeFocusOnTab: true
            onActiveFocusChanged: if (activeFocus) selectAll()
            onEditingFinished: {
                const typed = parseInt(text);
                const next = isNaN(typed) ? field.value : Math.max(field.least, Math.min(field.most, typed));
                text = Qt.binding(() => field.value);
                if (next !== field.value)
                    field.took(next);
            }
        }
    }
    component Push: Rectangle {
        id: push
        property string text
        signal clicked()
        width: Math.ceil(pushLabel.implicitWidth) + 24
        height: 22
        radius: 6
        color: pushTap.pressed ? Qt.tint(settings.face, settings.dark ? "#18ffffff" : "#18000000") : settings.face
        Accessible.role: Accessible.Button
        Accessible.name: text
        Text {
            id: pushLabel
            anchors.centerIn: parent
            text: push.text
            color: settings.ink
            font.family: Theme.uiFont
            font.pixelSize: 13
            renderType: Text.NativeRendering
        }
        MouseArea { id: pushTap; anchors.fill: parent; onClicked: push.clicked() }
    }

    // The box, 65 to 366 down in the Mac's terms.
    Rectangle {
        x: 22
        y: 65 - settings.bar
        width: settings.width - 44
        height: 301
        radius: 6
        color: settings.boxFill
        border.width: 1
        border.color: settings.boxEdge
    }
    // The tabs, astride the box's top edge.
    Rectangle {
        id: tabs
        readonly property var names: ["New Document", "Open and Save"]
        x: (settings.width - width) / 2
        y: 53 - settings.bar
        width: 240
        height: 24
        radius: 7
        color: settings.dark ? Qt.tint(settings.boxFill, "#0affffff") : Qt.tint(settings.ground, "#0f000000")
        border.width: 0.5
        border.color: settings.boxEdge
        Repeater {
            model: tabs.names
            Rectangle {
                required property string modelData
                required property int index
                x: index * tabs.width / 2 + 1
                y: 1
                width: tabs.width / 2 - 2
                height: tabs.height - 2
                radius: 6
                color: settings.tab !== index ? "transparent" : settings.dark ? Qt.rgba(1, 1, 1, 0.13) : "#ffffff"
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData
                    color: settings.ink
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    renderType: Text.NativeRendering
                }
                MouseArea { anchors.fill: parent; onClicked: settings.tab = parent.index }
            }
        }
    }

    Item {
        id: fontRows
        visible: settings.tab === 0
        readonly property real buttonX: Math.max(127, 43 + Math.ceil(Math.max(plainLabel.implicitWidth, richLabel.implicitWidth)) + 7)

        Heading { mid: 92.5; text: "Format" }
        // Our letters run wider than a Mac's: the line is fitted to the box.
        Line { x: 43; mid: 113; width: 352; fontSizeMode: Text.HorizontalFit; minimumPixelSize: 11; text: "Use the Format menu to choose settings for an open document." }
        Radio { mid: 131; text: "Rich text"; chosen: Prefs.rich; onPicked: Prefs.rich = true }
        Radio { mid: 148.5; text: "Plain text"; chosen: !Prefs.rich; onPicked: Prefs.rich = false }

        Heading { mid: 175.5; text: "Window Size" }
        Line { x: 43; mid: 197.5; text: "Width:" }
        NumberField { mid: 197.5; value: Prefs.columns; least: 20; most: 400; onTook: (value) => Prefs.columns = value }
        Line { x: 146; mid: 197.5; text: "characters" }
        Line { x: 43; mid: 226; text: "Height:" }
        NumberField { mid: 226; value: Prefs.lines; least: 5; most: 200; onTook: (value) => Prefs.lines = value }
        Line { x: 146; mid: 226; text: "lines" }

        Heading { mid: 253; text: "Font" }
        // The two buttons start where the longer label ends (127 on a Mac).
        Line { id: plainLabel; x: 43; mid: 275; text: "Plain text font:" }
        Push { id: plainChange; x: fontRows.buttonX; y: 275 - settings.bar - 11; text: "Change…"; onClicked: fonts.choose(true, Prefs.plainFont, Prefs.plainSize) }
        Line { x: plainChange.x + plainChange.width + 11; mid: 275; text: Prefs.plainFont + " " + Prefs.plainSize }
        Line { id: richLabel; x: 43; mid: 299; text: "Rich text font:" }
        Push { x: fontRows.buttonX; y: 299 - settings.bar - 11; text: "Change…"; onClicked: fonts.choose(false, Prefs.richFamily, Prefs.richSize) }
        Line { x: plainChange.x + plainChange.width + 11; mid: 299; text: Prefs.richFamily + " " + Prefs.richSize }

        Heading { mid: 326; text: "Options" }
        Check { mid: 348; text: "Show ruler"; checked: Prefs.ruler; onToggled: Prefs.ruler = !checked }
    }

    Item {
        id: encodingRows
        visible: settings.tab === 1
        readonly property real popX: Math.max(123, 43 + Math.ceil(Math.max(openingLabel.implicitWidth, savingLabel.implicitWidth)) + 8)
        readonly property var encodings: [
            { text: "Automatic", value: "auto" },
            {},
            { text: "Unicode (UTF-8)", value: "utf-8" },
            { text: "Unicode (UTF-16)", value: "utf-16" },
            { text: "Western (ISO Latin 1)", value: "latin1" },
        ]

        Heading { mid: 86.5; text: "When Opening a File:" }
        Check { mid: 106; text: "Display RTF files as RTF code instead of formatted text"; checked: Prefs.rtfAsCode; onToggled: Prefs.rtfAsCode = !checked }

        Heading { mid: 136; text: "When Saving a File:" }
        Check { mid: 156.5; text: "Add “.txt” extension to plain text files"; checked: Prefs.addTxt; onToggled: Prefs.addTxt = !checked }

        Heading { mid: 186; text: "Plain Text File Encoding" }
        // The pop-ups start where the longer label ends (123 on a Mac).
        Line { id: openingLabel; x: 43; mid: 209.5; text: "Opening files:" }
        PrefPopup {
            x: encodingRows.popX; y: 209.5 - settings.bar - 12; width: 371 - x
            items: parent.encodings
            current: Prefs.openEncoding
            onChosen: (value) => Prefs.openEncoding = value
        }
        Line { id: savingLabel; x: 43; mid: 235.5; text: "Saving files:" }
        PrefPopup {
            x: encodingRows.popX; y: 235.5 - settings.bar - 12; width: 371 - x
            items: parent.encodings
            current: Prefs.saveEncoding
            onChosen: (value) => Prefs.saveEncoding = value
        }
    }

    Push {
        x: 21
        y: 377 - settings.bar
        height: 24
        text: "Restore All Defaults"
        onClicked: Prefs.restore()
    }

    // Change…: the platform's font panel.
    Platform.FontDialog {
        id: fonts
        property bool plain: true
        // The panel shows the font in use: told once it is up (before
        // that there is no panel to tell), by the family that stands in
        // for it here (Helvetica is a name the system answers to, not a
        // font in its list).
        function choose(plain, family, size) {
            fonts.plain = plain;
            probe.font.family = family;
            const now = Qt.font({ family: probe.fontInfo.family, pointSize: size });
            fonts.open();
            fonts.currentFont = now;
        }
        onAccepted: {
            if (plain) {
                Prefs.plainFamily = font.family;
                Prefs.plainSize = Math.round(font.pointSize);
            } else {
                Prefs.richFamily = font.family;
                Prefs.richSize = Math.round(font.pointSize);
            }
        }
    }

    Text { id: probe; visible: false }

    Shortcut { sequences: ["Ctrl+W"]; onActivated: settings.close() }
}
