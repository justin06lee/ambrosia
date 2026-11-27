import QtQuick
import Ambrosia
import Files

// Files' Settings (Finder Settings on a Mac), from the Files menu or ⌘,:
// the kit's Settings window with three tabs, laid out as macOS 27's Finder
// Settings is. Only what Files really does is here: no desktop items, no
// tabs in windows, no Tags tab yet. Each control sets Prefs, which every
// window reads live.
PreferencesWindow {
    id: settings

    title: "Files Settings"
    current: Prefs.tab
    onCurrentChanged: Prefs.tab = current
    tabs: [
        { title: "General", glyph: "gear", page: general },
        { title: "Sidebar", glyph: "sidebar", page: sidebar },
        { title: "Advanced", glyph: "gears", page: advanced },
    ]

    // A line of text centered on a y, as the Mac's rows are measured.
    component Line: Label {
        property real mid
        y: mid - height / 2
        color: settings.colors.label.primary
    }
    component Pop: PrefPopup {}

    Component {
        id: general

        Item {
            implicitHeight: 89

            Line { x: 28; mid: 28.5; text: "New Files windows show:" }
            Pop {
                x: 48
                y: 44.5
                width: 284
                items: [
                    { text: "Recents", value: "recents" },
                    {},
                    { text: Places.computer, value: "computer" },
                    { text: Places.place("home").toString().replace(/\/$/, "").split("/").pop(), value: "home" },
                    { text: "Desktop", value: "desktop" },
                    { text: "Documents", value: "documents" },
                    { text: "Downloads", value: "downloads" },
                ]
                current: Prefs.newWindow
                onChosen: (value) => Prefs.newWindow = value
            }
        }
    }

    Component {
        id: sidebar

        Item {
            id: list

            // The sidebar's own order (Places::sections), a title before
            // each section. `id` is what Prefs keeps.
            readonly property var rows: [
                { id: "recents", text: "Recents", glyph: "recents" },
                { header: "Favorites" },
                { id: "applications", text: "Applications", glyph: "applications" },
                { id: "desktop", text: "Desktop", glyph: "desktop" },
                { id: "documents", text: "Documents", glyph: "documents" },
                { id: "downloads", text: "Downloads", glyph: "downloads" },
                { id: "movies", text: "Movies", glyph: "movies" },
                { id: "music", text: "Music", glyph: "music" },
                { id: "pictures", text: "Pictures", glyph: "pictures" },
                { header: "Locations" },
                { id: "home", text: Places.place("home").toString().replace(/\/$/, "").split("/").pop(), glyph: "home" },
                { id: "computer", text: Places.computer, glyph: "drive" },
                { id: "disks", text: "Hard disks", glyph: "drive" },
                { id: "external", text: "External disks", glyph: "external" },
                { id: "trash", text: "Trash", glyph: "trash" },
                { header: "Tags" },
                { id: "tags", text: "Recent Tags", glyph: "tag" },
            ]
            // Each row's middle: rows 28 apart, a title 32.5 under the row
            // before it and 22.5 over the one after.
            readonly property var mids: {
                const out = [];
                let y = 58.5 - 28;
                for (let i = 0; i < rows.length; ++i) {
                    y += rows[i].header ? 32.5 : i > 0 && rows[i - 1].header ? 22.5 : 28;
                    out.push(y);
                }
                return out;
            }
            // Prefs says its list changed, not which item: read again.
            property int revision: 0
            Connections {
                target: Prefs
                function onSidebarChanged() { list.revision += 1 }
            }

            implicitHeight: mids[mids.length - 1] + 40.5

            Line { x: 28; mid: 28.5; text: "Show these items in the sidebar:" }
            Repeater {
                model: list.rows

                Item {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool shows: (list.revision, modelData.id ? Prefs.sidebarShows(modelData.id) : false)

                    y: list.mids[index]
                    width: list.width

                    Line {
                        visible: row.modelData.header !== undefined
                        x: 40.5
                        mid: 0
                        text: row.modelData.header ?? ""
                        style: Theme.text.caption
                        font.weight: Font.Bold
                        color: settings.colors.label.secondary
                    }
                    PrefCheck {
                        visible: row.modelData.id !== undefined
                        x: 41
                        y: -7
                        box: 14
                        checked: row.shows
                        Accessible.name: row.modelData.text ?? ""
                        onToggled: Prefs.setSidebarShows(row.modelData.id, !row.shows)
                    }
                    Glyph {
                        visible: row.modelData.id !== undefined
                        x: 60
                        y: -8
                        size: 16
                        name: row.modelData.glyph ?? ""
                        color: settings.colors.label.secondary
                    }
                    Line {
                        visible: row.modelData.id !== undefined
                        x: 81
                        mid: 0
                        text: row.modelData.text ?? ""
                        color: settings.colors.label.secondary
                    }
                    // The whole row takes the click, as the Mac's does.
                    MouseArea {
                        enabled: row.modelData.id !== undefined
                        x: 41
                        y: -12
                        width: 250
                        height: 24
                        onClicked: Prefs.setSidebarShows(row.modelData.id, !row.shows)
                    }
                }
            }
        }
    }

    Component {
        id: advanced

        Item {
            implicitHeight: 226

            PrefCheck {
                x: 28; y: 20
                text: "Show warning before changing an extension"
                checked: Prefs.warnExtension
                onToggled: Prefs.warnExtension = !checked
            }
            PrefCheck {
                x: 28; y: 46
                text: "Show warning before emptying the Trash"
                checked: Prefs.warnEmptyTrash
                onToggled: Prefs.warnEmptyTrash = !checked
            }
            PrefCheck {
                x: 28; y: 72
                text: "Remove items from the Trash after 30 days"
                checked: Prefs.trashExpires
                onToggled: Prefs.trashExpires = !checked
            }
            Line { x: 28; mid: 106.5; text: "Keep folders on top:" }
            PrefCheck {
                x: 50; y: 124
                text: "In windows when sorting by name"
                checked: Prefs.foldersFirst
                onToggled: Prefs.foldersFirst = !checked
            }
            Line { x: 28; mid: 166.5; text: "When performing a search:" }
            Pop {
                x: 50
                y: 182
                width: 237.5
                items: [
                    { text: "Search This Computer", value: "computer" },
                    { text: "Search the Current Folder", value: "folder" },
                    { text: "Use the Previous Search Scope", value: "previous" },
                ]
                current: Prefs.searchScope
                onChosen: (value) => Prefs.searchScope = value
            }
        }
    }
}
