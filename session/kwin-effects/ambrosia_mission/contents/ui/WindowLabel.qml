import QtQuick
import Ambrosia

// A window's name under it in Mission Control: its app's icon and its title
// on a capsule.
Item {
    id: label

    property string text
    // Draws the app's icon, filling its parent.
    property Component icon
    // The widest it may be; a longer title is cut short.
    property real maxWidth: 320

    readonly property int pad: Theme.space.s2
    readonly property int iconSize: Theme.size.mission.label - 2 * Theme.space.s1

    implicitHeight: Theme.size.mission.label
    implicitWidth: Math.min(maxWidth, pad + iconSize + Theme.space.s2 + title.implicitWidth + pad + Theme.space.s1)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.color.material.thick.tint
        border.width: 1
        border.color: Theme.color.glass.edge
    }

    Loader {
        x: label.pad
        y: (label.height - height) / 2
        width: label.iconSize
        height: label.iconSize
        sourceComponent: label.icon
    }

    Label {
        id: title
        x: label.pad + label.iconSize + Theme.space.s2
        width: label.width - x - label.pad
        height: label.height
        text: label.text
        style: Theme.text.callout
        elide: Text.ElideRight
        textFormat: Text.PlainText
    }
}
