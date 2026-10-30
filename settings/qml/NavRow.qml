import QtQuick
import Ambrosia
import Settings

// A row that opens a page (General's About, Date & Time…): the page's icon,
// its name and a chevron. A page we haven't built opens its KDE module.
Item {
    id: row

    required property var settings
    required property var pane

    width: parent ? parent.width : Look.boxWidth
    height: Look.navRow

    PaneIcon {
        x: Look.navIconX
        anchors.verticalCenter: parent.verticalCenter
        glyph: row.pane.glyph
        tint: row.pane.tint
    }
    Label {
        x: Look.navLabelX
        width: chevron.x - x - 8
        anchors.verticalCenter: parent.verticalCenter
        text: row.pane.name
        elide: Text.ElideRight
    }
    Glyph {
        id: chevron
        x: row.width - Look.chevronRight - width + 3
        anchors.verticalCenter: parent.verticalCenter
        name: "chevronRight"
        size: 12
        color: Theme.color.label.tertiary
    }
    MouseArea {
        anchors.fill: parent
        onClicked: row.settings.choose(row.pane.id)
    }
}
