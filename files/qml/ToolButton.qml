import QtQuick
import Ambrosia

// A glyph button inside a toolbar capsule.
Item {
    id: button

    property string glyph
    property real glyphSize: Finder.toolbarGlyph
    property bool enabled_: true
    property bool selected: false
    property real pillWidth: Finder.segmentPillWidth
    signal clicked()

    implicitWidth: Finder.segment
    implicitHeight: Finder.control

    Rectangle {
        anchors.centerIn: parent
        width: button.pillWidth
        height: Finder.segmentPill
        radius: height / 2
        color: Finder.segmentSelected
        visible: button.selected
    }
    Rectangle {
        anchors.centerIn: parent
        width: button.pillWidth
        height: Finder.segmentPill
        radius: height / 2
        color: Theme.color.fill.tertiary
        visible: tap.pressed && button.enabled_
    }
    Glyph {
        anchors.centerIn: parent
        name: button.glyph
        size: button.glyphSize
        color: button.enabled_ ? Theme.color.label.primary : Theme.color.label.tertiary
    }
    TapHandler {
        id: tap
        enabled: button.enabled_
        onTapped: button.clicked()
    }
}
