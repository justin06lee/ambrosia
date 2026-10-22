import QtQuick
import Ambrosia

// The toolbar's search field, as Finder's search button opens into: the
// magnifier, a token once a suggestion is chosen, what's typed, and the
// clear button, ringed in the accent color while it has the keyboard.
// Under it while typing, Finder's suggestions: "Name Contains" (names
// only) and "Contains" (what's in files); one chosen becomes the token.
Item {
    id: field

    required property var finder
    readonly property string typed: finder.searchText.trim()
    readonly property var suggestions: finder.searchToken || typed === "" ? [] : [
        { header: "Filenames", text: "Name Contains “" + typed + "”", mode: "name" },
        { header: "Content", text: "Contains “" + typed + "”", mode: "content" },
    ]
    property bool suggesting: false
    property int lit: -1
    readonly property bool suggestionsShown: suggesting && suggestions.length > 0 && input.activeFocus

    function focusField() {
        input.forceActiveFocus();
    }
    function choose(i) {
        const s = suggestions[i];
        suggesting = false;
        lit = -1;
        if (s)
            finder.chooseSearchToken(s.mode);
    }

    implicitWidth: Finder.searchField
    implicitHeight: Finder.control

    Rectangle {
        // The focus ring.
        visible: input.activeFocus
        anchors.fill: parent
        anchors.margins: -Finder.searchRing
        radius: height / 2
        color: "transparent"
        border.width: Finder.searchRing
        border.color: Qt.alpha(Theme.accent.bg, 0.55)
    }
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Finder.searchFill
        border.width: 0.5
        border.color: Finder.capsuleRim
    }
    Glyph {
        x: Finder.searchGlyphX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        name: "search"
        size: 16
        color: Theme.color.label.secondary
    }

    // The token: what it searches (NAME, CONTENTS) and the words.
    Row {
        id: token
        visible: field.finder.searchToken !== null
        x: Finder.searchTextX + 4
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
            width: mode.implicitWidth + 17
            height: Finder.tokenHeight
            topLeftRadius: 4
            bottomLeftRadius: 4
            color: Finder.tokenMode
            Label {
                id: mode
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                text: field.finder.searchToken?.mode === "content" ? "CONTENTS" : "NAME"
                style: Theme.text.caption
                font.pixelSize: 10
                font.weight: 700
                color: "white"
            }
            Glyph {
                x: parent.width - 11
                anchors.verticalCenter: parent.verticalCenter
                name: "chevronDown"
                size: 9
                weight: 2.6
                color: "white"
            }
        }
        Rectangle {
            width: words.implicitWidth + 8
            height: Finder.tokenHeight
            topRightRadius: 4
            bottomRightRadius: 4
            color: Finder.tokenText
            Label {
                id: words
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                text: field.finder.searchToken?.text ?? ""
                color: Theme.color.label.primary
            }
        }
    }

    TextInput {
        id: input
        x: token.visible ? token.x + token.width + 3 : Finder.searchTextX
        width: Math.max(0, clear.x - 6 - x)
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        font.family: Theme.uiFont
        font.pixelSize: Theme.text.body.size
        font.weight: Theme.text.body.weight
        color: Theme.color.label.primary
        selectionColor: Theme.accent.bg
        selectedTextColor: Theme.accent.fg
        selectByMouse: true
        renderType: Text.NativeRendering
        onTextEdited: {
            field.suggesting = text.trim() !== "";
            field.lit = -1;
            field.finder.typeSearch(text);
        }
        onActiveFocusChanged: if (!activeFocus) field.suggesting = false
        Keys.onPressed: (event) => {
            const n = field.suggestions.length;
            switch (event.key) {
            case Qt.Key_Down:
                if (n > 0) {
                    field.suggesting = true;
                    field.lit = (field.lit + 1) % n;
                }
                break;
            case Qt.Key_Up:
                if (n > 0 && field.suggesting)
                    field.lit = Math.max(0, field.lit - 1);
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
                if (field.suggestionsShown && field.lit >= 0)
                    field.choose(field.lit);
                else
                    field.suggesting = false;
                break;
            case Qt.Key_Escape:
                if (field.suggestionsShown)
                    field.suggesting = false;
                else
                    field.finder.closeSearch();
                break;
            case Qt.Key_Backspace:
                if (text === "" && field.finder.searchToken) {
                    field.finder.removeSearchToken();
                    break;
                }
                return;
            case Qt.Key_Tab:
                field.finder.focusResults();
                break;
            default:
                return;
            }
            event.accepted = true;
        }
        Connections {
            target: field.finder
            function onSearchTextChanged() {
                if (input.text !== field.finder.searchText)
                    input.text = field.finder.searchText;
            }
        }
        Component.onCompleted: text = field.finder.searchText
    }

    // The clear button ends the search.
    Rectangle {
        id: clear
        visible: field.finder.searchText !== "" || field.finder.searchToken !== null
        x: parent.width - Finder.searchClearX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: Finder.searchClear
        height: width
        radius: width / 2
        color: Finder.clearFill
        Repeater {
            model: [45, -45]
            Rectangle {
                required property var modelData
                anchors.centerIn: parent
                width: 7.5
                height: 1.6
                radius: 0.8
                rotation: modelData
                color: Finder.searchFill
            }
        }
        TapHandler {
            onTapped: field.finder.closeSearch()
        }
    }

    // Finder's suggestions, under the field.
    Rectangle {
        visible: field.suggestionsShown
        x: 1
        y: field.height
        width: field.width - 2
        height: Finder.suggestHeight
        radius: 10
        color: Finder.suggestFill
        border.width: 0.5
        border.color: Finder.menuRim

        Repeater {
            model: field.suggestions
            Item {
                id: suggestion
                required property var modelData
                required property int index
                width: parent.width
                y: 11 + index * 57
                height: 46
                Label {
                    x: 15
                    y: 0
                    height: 18
                    verticalAlignment: Text.AlignVCenter
                    text: suggestion.modelData.header
                    style: Theme.text.caption
                    font.weight: 600
                    color: Theme.color.label.tertiary
                }
                Rectangle {
                    visible: field.lit === suggestion.index
                    x: 7
                    y: 18
                    width: parent.width - 14
                    height: 22
                    radius: 5
                    color: Theme.accent.bg
                }
                Label {
                    x: 17
                    y: 18
                    height: 22
                    verticalAlignment: Text.AlignVCenter
                    text: suggestion.modelData.text
                    color: field.lit === suggestion.index ? Theme.accent.fg : Theme.color.label.primary
                }
                HoverHandler {
                    onHoveredChanged: if (hovered) field.lit = suggestion.index
                }
                TapHandler {
                    onTapped: field.choose(suggestion.index)
                }
            }
        }
        Rectangle {
            x: 13
            y: 59
            width: parent.width - 26
            height: 1
            color: Finder.suggestRule
        }
    }
}
