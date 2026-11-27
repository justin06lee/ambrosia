import QtQuick
import QtQuick.Controls.Basic as Controls
import Qt.labs.platform as Platform
import Ambrosia
import Notes
import "notes.mjs" as Logic

// The note: when it was last changed, small and centered, over its text.
// The TextEdit shows the document; the window's Editor (`hands`) keeps it a
// note and says where the marks go, which are drawn here beside the text:
// a list's bullets, dashes and numbers, a checklist's rings (a click ticks
// one) and the bar beside quoted paragraphs.
Item {
    id: pane

    required property var window
    required property var hands
    readonly property alias edit: edit
    readonly property bool front: window.looksActive
    // Counts up whenever the text is laid out anew: the marks follow.
    property int laid: 0

    function toTop() {
        flick.contentY = 0;
    }
    // Keeps the insertion point in sight.
    function reveal() {
        if (!edit.activeFocus)
            return;
        const at = edit.cursorRectangle;
        const top = edit.y + at.y, bottom = top + at.height;
        if (top < flick.contentY + 4)
            flick.contentY = Math.max(0, top - 12);
        else if (bottom > flick.contentY + flick.height - 4)
            flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), bottom + 12 - flick.height);
    }

    Rectangle {
        anchors.fill: parent
        color: Look.noteFill
    }

    Flickable {
        id: flick
        anchors.fill: parent
        visible: pane.window.open !== null
        contentWidth: width
        contentHeight: edit.y + edit.height
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        Controls.ScrollBar.vertical: ScrollThumb {}

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Look.noteDateY - height / 2
            text: pane.window.open ? Logic.longDate(pane.window.shownDate, App.hour24) : ""
            style: Theme.text.callout
            color: Look.faint
        }

        TextEdit {
            id: edit
            y: Look.noteTextY
            width: flick.width
            height: Math.max(implicitHeight, flick.height - y)
            textFormat: TextEdit.RichText
            font.family: Theme.uiFont
            font.pixelSize: 13
            leftPadding: Look.noteInset
            rightPadding: Look.noteInset
            bottomPadding: 24
            wrapMode: TextEdit.Wrap
            tabStopDistance: 28
            color: Look.noteText
            selectionColor: pane.front ? Look.selection : Look.selectionInactive
            selectedTextColor: Look.noteText
            selectByMouse: true
            persistentSelection: true
            readOnly: !pane.window.editable
            cursorDelegate: caret
            Accessible.name: "Note"
            onCursorRectangleChanged: pane.reveal()
            onContentSizeChanged: pane.laid += 1
            onWidthChanged: pane.laid += 1
            onTextChanged: pane.laid += 1

            Keys.onPressed: (event) => {
                const command = event.modifiers & (Qt.ControlModifier | Qt.MetaModifier);
                const bare = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier));
                // The clipboard is the Editor's: paragraphs whole between
                // notes, text alone from anywhere else.
                if (command && !(event.modifiers & (Qt.AltModifier | Qt.ShiftModifier))) {
                    if (event.key === Qt.Key_C) {
                        pane.hands.copy();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_X) {
                        if (!edit.readOnly)
                            pane.hands.cut();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_V) {
                        if (!edit.readOnly)
                            pane.hands.paste();
                        event.accepted = true;
                    }
                    return;
                }
                if (edit.readOnly || !bare)
                    return;
                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier))
                    event.accepted = pane.hands.returnKey();
                else if (event.key === Qt.Key_Tab)
                    event.accepted = pane.hands.indent(1);
                else if (event.key === Qt.Key_Backtab)
                    event.accepted = pane.hands.indent(-1);
                else if (event.key === Qt.Key_Backspace)
                    event.accepted = pane.hands.backspaceKey();
            }
        }

        // The marks beside the text.
        Repeater {
            model: pane.hands.markers

            Item {
                id: mark
                required property var modelData
                // Where the paragraph's first line is, and its last.
                readonly property rect first: pane.laid >= 0 ? edit.positionToRectangle(modelData.start) : Qt.rect(0, 0, 0, 0)
                readonly property rect last: pane.laid >= 0 ? edit.positionToRectangle(modelData.last) : Qt.rect(0, 0, 0, 0)
                // Where its text begins.
                readonly property real textX: edit.leftPadding + modelData.x

                y: edit.y + first.y
                width: flick.width
                height: first.height

                Rectangle {
                    visible: mark.modelData.quote
                    x: edit.leftPadding + 1
                    width: 3
                    // (To the next line's top: one quoted paragraph after
                    // another has one bar.)
                    height: mark.last.y + mark.last.height - mark.first.y + 1
                    color: Look.quoteBar
                }
                Label {
                    visible: mark.modelData.kind === "bullet" || mark.modelData.kind === "dash" || mark.modelData.kind === "number"
                    x: mark.textX - width - (mark.modelData.kind === "number" ? 5 : 9)
                    y: (parent.height - height) / 2
                    text: mark.modelData.kind === "number" ? mark.modelData.number + "." : mark.modelData.kind === "dash" ? "–" : "•"
                    font.pixelSize: 13
                    color: Look.noteText
                }
                Rectangle {
                    id: ring
                    visible: mark.modelData.kind === "check"
                    x: mark.textX - 25
                    y: (parent.height - height) / 2
                    width: 17
                    height: 17
                    radius: 8.5
                    color: mark.modelData.checked ? Look.tint : "transparent"
                    border.width: mark.modelData.checked ? 0 : 1.25
                    border.color: Look.ring
                    Accessible.role: Accessible.CheckBox
                    Accessible.name: mark.modelData.checked ? "Checked" : "Unchecked"
                    Glyph {
                        visible: mark.modelData.checked
                        anchors.centerIn: parent
                        name: "check"
                        size: 12
                        weight: 2.6
                        color: Look.dark ? "#1c1c1c" : "#ffffff"
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -3
                        enabled: pane.window.editable
                        onClicked: pane.hands.toggleChecked(mark.modelData.start)
                    }
                }
            }
        }

        // Right-click: the usual three.
        MouseArea {
            x: edit.x
            y: edit.y
            width: edit.width
            height: edit.height
            acceptedButtons: Qt.RightButton
            cursorShape: Qt.IBeamCursor
            onClicked: {
                edit.forceActiveFocus();
                context.open();
            }
        }
    }

    // The insertion point: Notes' yellow, two wide.
    Component {
        id: caret
        Rectangle {
            id: point
            width: 2
            radius: 1
            color: Look.tint
            visible: edit.activeFocus && !edit.readOnly && edit.selectionStart === edit.selectionEnd
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

    Platform.Menu {
        id: context
        Platform.MenuItem { text: "Cut"; enabled: pane.window.editable && edit.selectedText !== ""; onTriggered: pane.hands.cut() }
        Platform.MenuItem { text: "Copy"; enabled: edit.selectedText !== ""; onTriggered: pane.hands.copy() }
        Platform.MenuItem { text: "Paste"; enabled: pane.window.editable; onTriggered: pane.hands.paste() }
    }
}
