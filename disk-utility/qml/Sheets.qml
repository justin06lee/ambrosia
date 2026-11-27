import QtQuick
import QtQuick.Controls.Basic as Controls
import QtQuick.Effects
import Ambrosia
import DiskUtility
import "disks.mjs" as Logic

// What Disk Utility asks and tells over its window, which dims under it
// (Look.qml, measured from macOS 27's Erase and First Aid sheets): the
// Erase form (a name, a format, and for a whole disk a scheme), an alert
// that asks before First Aid or says what went wrong, the password of an
// encrypted volume, and the sheet that stays while First Aid or an erase
// runs, with what it did under Show Details. Return presses the button in
// the accent color, Escape the other.
Rectangle {
    id: sheets

    required property var window
    // "", erase, alert, unlock or progress
    property string mode: ""
    property string icon: "internal"
    property string title
    property string detail
    // erase
    property var formats: []
    property bool whole: false
    property string format
    property string scheme: "gpt"
    property var onErase: null
    // alert: [{ text, role, primary, cancel }], and what to do with the role
    property var buttons: []
    property var then: null
    // unlock
    property bool wrong: false
    property bool unlocking: false
    property var onUnlock: null
    // progress
    property var lines: []
    property bool running: false
    property bool ok: true
    property bool details: false
    property string doneTitle
    property string doneText

    function askErase(icon, name, whole, formats, format, then) {
        sheets.icon = icon;
        sheets.title = "Erase “" + name + "”?";
        sheets.detail = whole
            ? "Erasing “" + name + "” will permanently erase all data stored on it. Keep the device connected until the erase completes. You can’t undo this action."
            : "Data on “" + name + "” will be deleted, but may still be accessible with recovery tools. Keep the device connected until the erase completes. You can’t undo this action.";
        sheets.whole = whole;
        sheets.formats = formats;
        sheets.format = formats.some(entry => entry.type === format) ? format : (formats[0]?.type ?? "");
        sheets.scheme = "gpt";
        sheets.onErase = then;
        nameBox.input.text = whole ? "Untitled" : name;
        mode = "erase";
        nameBox.input.forceActiveFocus();
        nameBox.input.selectAll();
    }
    function ask(icon, title, detail, buttons, then) {
        sheets.icon = icon;
        sheets.title = title;
        sheets.detail = detail;
        sheets.buttons = buttons;
        sheets.then = then;
        mode = "alert";
        card.forceActiveFocus();
    }
    function askPassword(icon, name, then) {
        sheets.icon = icon;
        sheets.title = "Enter a password to unlock the disk “" + name + "”.";
        sheets.detail = "";
        sheets.wrong = false;
        sheets.unlocking = false;
        sheets.onUnlock = then;
        passwordBox.input.text = "";
        mode = "unlock";
        passwordBox.input.forceActiveFocus();
    }
    function wrongPassword() {
        sheets.unlocking = false;
        sheets.wrong = true;
        passwordBox.input.forceActiveFocus();
        passwordBox.input.selectAll();
    }
    function progress(icon, title, doneTitle, doneText) {
        sheets.icon = icon;
        sheets.title = title;
        sheets.doneTitle = doneTitle;
        sheets.doneText = doneText;
        sheets.lines = [];
        sheets.running = true;
        sheets.ok = true;
        sheets.details = false;
        mode = "progress";
        card.forceActiveFocus();
    }
    function say(line) {
        sheets.lines = sheets.lines.concat([line]);
    }
    function finish(ok, title, text) {
        sheets.running = false;
        sheets.ok = ok;
        sheets.doneTitle = title;
        sheets.doneText = text;
    }
    function close() {
        mode = "";
        window.takeKeys();
    }
    function accept() {
        if (mode === "erase") {
            const then = sheets.onErase;
            const name = Logic.labelFor(sheets.format, nameBox.input.text);
            const format = sheets.format, scheme = sheets.whole ? sheets.scheme : "";
            if (format === "")
                return;
            close();
            if (then)
                then(name, format, scheme);
        } else if (mode === "alert") {
            answer((sheets.buttons.find(button => button.primary) ?? sheets.buttons[0]).role);
        } else if (mode === "unlock") {
            if (passwordBox.input.text === "" || sheets.unlocking)
                return;
            sheets.unlocking = true;
            sheets.wrong = false;
            if (sheets.onUnlock)
                sheets.onUnlock(passwordBox.input.text);
        } else if (mode === "progress" && !sheets.running) {
            close();
        }
    }
    function cancel() {
        if (mode === "alert") {
            const button = sheets.buttons.find(button => button.cancel);
            if (button)
                answer(button.role);
        } else if (mode === "erase" || mode === "unlock") {
            close();
        } else if (mode === "progress" && !sheets.running) {
            close();
        }
    }
    function answer(role) {
        const then = sheets.then;
        sheets.then = null;
        close();
        if (then)
            then(role);
    }

    visible: mode !== ""
    radius: window.corner
    color: Look.dim
    // Nothing under the card takes a click while it asks.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true; onWheel: (wheel) => wheel.accepted = true }

    component Field: Rectangle {
        property alias input: input
        width: 256
        height: 24
        radius: 6
        color: Look.field
        border.width: input.activeFocus ? 2.5 : 0.5
        border.color: input.activeFocus ? Theme.accent.bg : Look.fieldRim
        TextInput {
            id: input
            x: 7
            width: parent.width - 14
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            font.family: Theme.uiFont
            font.pixelSize: 13
            color: Theme.color.label.primary
            selectionColor: Theme.accent.highlight
            selectedTextColor: Theme.color.label.primary
            renderType: Text.NativeRendering
            selectByMouse: true
            Keys.onReturnPressed: sheets.accept()
            Keys.onEnterPressed: sheets.accept()
            Keys.onEscapePressed: sheets.cancel()
        }
    }
    component FieldName: Label {
        x: 138 - implicitWidth
        font.pixelSize: 13
    }

    Rectangle {
        id: card
        readonly property bool narrow: sheets.mode === "alert"
        anchors.centerIn: parent
        width: narrow ? Look.alertWidth : Look.sheetWidth
        height: sheets.mode === "alert" ? alertBody.height
              : sheets.mode === "erase" ? (sheets.whole ? 258 : 226)
              : sheets.mode === "unlock" ? 150
              : sheets.mode === "progress" ? (sheets.details ? 318 : 134) : 0
        radius: narrow ? Look.alertRadius : Look.sheetRadius
        color: Look.sheetFill
        border.width: 0.5
        border.color: Look.sheetRim
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: 0.3
            shadowBlur: 1
            shadowVerticalOffset: 8
            blurMax: 48
        }
        Keys.onReturnPressed: sheets.accept()
        Keys.onEnterPressed: sheets.accept()
        Keys.onEscapePressed: sheets.cancel()

        DiskIcon {
            x: 19
            y: 19
            kind: sheets.icon
        }

        // A form's words, beside the picture.
        Label {
            id: formTitle
            visible: !card.narrow
            x: 91
            y: 19
            width: card.width - x - 19
            elide: Text.ElideRight
            text: sheets.mode === "progress" && !sheets.running ? sheets.doneTitle : sheets.title
            font.weight: 700
        }
        Label {
            visible: sheets.mode === "erase" || (sheets.mode === "progress" && !sheets.running)
            x: 91
            y: 43
            width: card.width - x - 19
            wrapMode: Text.Wrap
            text: sheets.mode === "progress" ? sheets.doneText : sheets.detail
            style: Theme.text.footnote
        }

        // Erase: the name, the format, the scheme.
        Item {
            visible: sheets.mode === "erase"
            anchors.fill: parent
            FieldName { y: 110; text: "Name:" }
            Field { id: nameBox; x: 145; y: 106 }
            FieldName { y: 142; text: "Format:" }
            PrefPopup {
                x: 145
                y: 138
                width: 256
                items: sheets.formats.map(entry => ({ text: entry.name, value: entry.type }))
                current: sheets.format
                onChosen: (value) => sheets.format = value
            }
            FieldName { visible: sheets.whole; y: 174; text: "Scheme:" }
            PrefPopup {
                visible: sheets.whole
                x: 145
                y: 170
                width: 256
                items: Logic.schemes.map(entry => ({ text: entry.name, value: entry.key }))
                current: sheets.scheme
                onChosen: (value) => sheets.scheme = value
            }
        }

        // The password.
        Item {
            visible: sheets.mode === "unlock"
            anchors.fill: parent
            FieldName { x: 160 - implicitWidth; y: 62; text: "Password:" }
            Field { id: passwordBox; x: 167; y: 58; input.echoMode: TextInput.Password; input.enabled: !sheets.unlocking }
            Label {
                visible: sheets.wrong
                x: 167
                y: 86
                text: "That password didn’t unlock it."
                style: Theme.text.footnote
                color: Look.dark ? "#ff6961" : "#d70015"
            }
        }

        // While it runs: a bar that goes to and fro. Then what it did.
        Item {
            visible: sheets.mode === "progress"
            anchors.fill: parent
            Rectangle {
                id: track
                visible: sheets.running
                x: 91
                y: 48
                width: card.width - x - 19
                height: 6
                radius: 3
                color: Look.dark ? "#4a4847" : "#dcdcdc"
                clip: true
                Rectangle {
                    id: runner
                    width: 110
                    height: parent.height
                    radius: 3
                    color: Theme.accent.bg
                    SequentialAnimation on x {
                        running: track.visible && sheets.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: -110; to: track.width; duration: 1400; easing.type: Easing.InOutSine }
                    }
                }
            }
            Item {
                x: 87
                y: 84
                width: showLabel.implicitWidth + 22
                height: 20
                Glyph {
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    name: sheets.details ? "chevronDown" : "chevronRight"
                    size: 11
                    color: Look.note
                }
                Label {
                    id: showLabel
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: sheets.details ? "Hide Details" : "Show Details"
                    style: Theme.text.footnote
                    font.weight: 600
                    color: Look.note
                }
                MouseArea { anchors.fill: parent; onClicked: sheets.details = !sheets.details }
            }
            Rectangle {
                visible: sheets.details
                x: 19
                y: 112
                width: card.width - 38
                height: 150
                radius: 6
                color: Look.logFill
                border.width: 0.5
                border.color: Look.fieldRim
                Flickable {
                    id: log
                    anchors.fill: parent
                    anchors.margins: 8
                    contentHeight: logText.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Controls.ScrollBar.vertical: ScrollThumb {}
                    onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
                    Label {
                        id: logText
                        width: log.width
                        wrapMode: Text.Wrap
                        text: sheets.lines.join("\n")
                        style: Theme.text.footnote
                        lineHeight: 1.15
                    }
                }
            }
        }

        // A form's buttons, at its foot from the right.
        Row {
            visible: !card.narrow
            anchors.right: parent.right
            anchors.rightMargin: 20
            y: card.height - 20 - 24
            spacing: 12
            PushButton {
                visible: sheets.mode !== "progress"
                width: 70
                text: "Cancel"
                onClicked: sheets.cancel()
            }
            PushButton {
                width: 70
                primary: true
                enabled: sheets.mode === "progress" ? !sheets.running
                       : sheets.mode === "unlock" ? passwordBox.input.text !== "" && !sheets.unlocking
                       : sheets.format !== ""
                text: sheets.mode === "erase" ? "Erase" : sheets.mode === "unlock" ? "Unlock" : "Done"
                onClicked: sheets.accept()
            }
        }

        // An alert: its words under the picture, its buttons side by side.
        Column {
            id: alertBody
            visible: card.narrow
            x: 21
            width: card.width - 42
            topPadding: 99
            bottomPadding: 16
            spacing: 8
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                text: sheets.title
                font.weight: 700
            }
            Label {
                width: parent.width
                visible: sheets.detail !== ""
                wrapMode: Text.Wrap
                text: sheets.detail
            }
            Item { width: 1; height: 6 }
            Row {
                x: -5
                spacing: 8
                Repeater {
                    model: sheets.buttons
                    PushButton {
                        required property var modelData
                        width: sheets.buttons.length === 1 ? 228 : 110
                        height: 28
                        radius: 14
                        text: modelData.text
                        primary: !!modelData.primary
                        onClicked: sheets.answer(modelData.role)
                    }
                }
            }
        }
    }
}
