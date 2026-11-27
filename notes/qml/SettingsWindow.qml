import QtQuick
import QtQuick.Window
import Ambrosia
import Notes

// Notes' Settings, from the Notes menu or ⌘,: the kit's window with its one
// page, as Notes' on a Mac has no tabs. Only what our Notes does is here:
// how the notes are sorted, whether they stand under dates, and what a new
// note's first line is. Each control sets Prefs, which the window reads
// live. The Mac's own Settings were not measured: the rows are laid out as
// Preview's.
PreferencesWindow {
    id: settings

    wide: 440
    title: "Settings"
    tabs: [{ title: "General", glyph: "gear", page: general }]

    // A row's name, ending where the controls begin, its middle at `mid`.
    component Name: Text {
        property real mid
        x: 196 - implicitWidth
        y: mid - height / 2
        color: settings.colors.label.primary
        font.family: Theme.uiFont
        font.pixelSize: 13
        renderType: Text.NativeRendering
    }

    Component {
        id: general
        Item {
            implicitHeight: 136
            Name { text: "Sort notes by:"; mid: 32 }
            PrefPopup {
                x: 205; y: 20; width: 170
                items: [{ text: "Date Edited", value: "edited" }, { text: "Date Created", value: "created" }, { text: "Title", value: "title" }]
                current: Prefs.sortBy
                onChosen: (value) => Prefs.sortBy = value
            }
            Name { text: "New notes start with:"; mid: 64 }
            PrefPopup {
                x: 205; y: 52; width: 170
                items: [{ text: "Title", value: "title" }, { text: "Heading", value: "heading" }, { text: "Subheading", value: "subheading" }, { text: "Body", value: "body" }]
                current: Prefs.firstLine
                onChosen: (value) => Prefs.firstLine = value
            }
            PrefCheck {
                x: 205; y: 88
                text: "Group notes by date"
                checked: Prefs.grouped
                enabled: Prefs.sortBy !== "title"
                onToggled: Prefs.grouped = !Prefs.grouped
            }
        }
    }
}
