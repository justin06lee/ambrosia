pragma Singleton
import QtQuick
import QtCore

// What Notes' Settings window and its View menu set, kept in
// ~/.config/ambrosia/notes.conf and read live: how the list is sorted and
// whether its notes stand under dates, and the kind of a new note's first
// line.
QtObject {
    // "edited", "created" or "title".
    property alias sortBy: saved.sortBy
    property alias grouped: saved.grouped
    // "title", "heading", "subheading" or "body".
    property alias firstLine: saved.firstLine

    property Settings saved: Settings {
        id: saved
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/ambrosia/notes.conf"
        category: "notes"
        property string sortBy: "edited"
        property bool grouped: true
        property string firstLine: "title"
    }
}
