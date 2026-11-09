import QtQuick
import Ambrosia
import Settings

// General: its header, then its pages in System Settings' groups (About,
// Software Update…; Date & Time, Language & Region, Login Items…), each
// opening ours or, until we build it, KDE's module.
Page {
    id: page
    header: headerBox

    HeaderBox { id: headerBox; pane: Panes.find("general") }

    Repeater {
        model: Panes.general.map(group => group.filter(pane => Panes.available(pane))).filter(group => group.length > 0)
        Box {
            id: box
            required property var modelData
            Repeater {
                model: box.modelData
                NavRow {
                    required property var modelData
                    settings: page.settings
                    pane: modelData
                }
            }
        }
    }
}
