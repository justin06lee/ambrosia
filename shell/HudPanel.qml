import QtQuick
import Ambrosia

// What the volume and brightness keys show: a glass capsule with a glyph and
// how far up its level is, or one line of text (the sound output that took
// over). Only the picture: Hud.qml puts it on screen and says what it shows.
Item {
    id: panel

    property string glyph: "speaker"
    // 0 to 1.
    property real level: 0
    // Shown in place of the level when there is any.
    property string text: ""

    implicitWidth: Theme.size.hud.width
    implicitHeight: Theme.size.hud.height

    Glass {
        anchors.fill: parent
        tint: Theme.color.material.regular.tint
        radius: height / 2
        shadow: Theme.color.shadow.panel
        ring: true
    }

    Icon {
        id: mark
        visible: panel.text === ""
        anchors { left: parent.left; leftMargin: Theme.size.hud.padding; verticalCenter: parent.verticalCenter }
        name: panel.glyph
        size: Theme.size.hud.glyph
    }

    // The same track as the control center's sliders, with no knob: it only
    // reports.
    Rectangle {
        visible: panel.text === ""
        anchors {
            left: mark.right; leftMargin: Theme.size.hud.gap
            right: parent.right; rightMargin: Theme.size.hud.padding + Theme.space.s0_5
            verticalCenter: parent.verticalCenter
        }
        height: Theme.size.controlCenter.track
        radius: height / 2
        color: Theme.color.fill.primary

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, panel.level))
            height: parent.height
            radius: Math.min(width, height) / 2
            color: Theme.color.label.primary

            Behavior on width { NumberAnimation { duration: Theme.fade.fast; easing.type: Easing.OutCubic } }
        }
    }

    Label {
        visible: panel.text !== ""
        anchors { fill: parent; leftMargin: Theme.size.hud.padding; rightMargin: Theme.size.hud.padding }
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: panel.text
        style: Theme.text.headline
    }
}
