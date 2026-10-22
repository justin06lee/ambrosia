import QtQuick
import Ambrosia

// Finder's quick actions under a preview, in its last 70 points: Rotate
// Left, Markup and More… for a picture, Markup and More… for a PDF, More…
// for anything else. None does anything yet, so each shows disabled.
Item {
    id: actions

    property string name // the item's, for its kind
    property bool picture

    readonly property var buttons: {
        const pdf = name.toLowerCase().endsWith(".pdf");
        return (picture && !pdf ? [["rotateLeft", "Rotate Left"], ["markup", "Markup"]] : pdf ? [["markup", "Markup"]] : [])
            .concat([["moreCircle", "More…"]]);
    }

    // Read once here: the buttons' bindings outlive the Finder singleton as
    // the window closes.
    readonly property real pitch: Finder.quickActionPitch
    readonly property real glyphMiddle: Finder.quickActionGlyph
    readonly property real labelBase: Finder.quickActionBase

    implicitHeight: Finder.previewPaneFoot

    Repeater {
        model: actions.buttons
        Item {
            id: button
            required property int index
            required property var modelData
            readonly property real middle: actions.width / 2 + (index - (actions.buttons.length - 1) / 2) * actions.pitch
            enabled: false

            Glyph {
                x: button.middle - width / 2
                y: actions.glyphMiddle - height / 2
                size: 20
                name: button.modelData[0]
                color: Theme.color.label.tertiary
            }
            Label {
                x: button.middle - width / 2
                y: actions.labelBase - baselineOffset
                style: Theme.text.caption
                text: button.modelData[1]
                color: Theme.color.label.tertiary
            }
        }
    }
}
