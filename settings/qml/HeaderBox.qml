import QtQuick
import Ambrosia
import Settings

// The box a parent pane opens with: its icon, its name and what it holds,
// centred.
Rectangle {
    id: header

    required property var pane

    width: Look.boxWidth
    height: Look.headerHeight
    radius: Look.boxRadius
    color: Look.box

    PaneIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Look.headerIconY
        size: Look.headerIcon
        glyph: header.pane.glyph
        tint: header.pane.tint
    }
    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Look.headerTitleY
        text: header.pane.name
        style: Theme.text.title1
    }
    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Look.headerTextY
        width: Look.headerTextWidth
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: header.pane.description ?? ""
        color: Theme.color.label.secondary
    }
}
