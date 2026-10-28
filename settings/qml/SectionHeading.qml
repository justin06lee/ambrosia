import QtQuick
import Ambrosia
import Settings

// A section's heading over its box: 13 points bold, 30 below the box above
// (the page's 10 between boxes and 20 of its own) and 26 above its box.
// The first thing on a page sits 4 under the toolbar.
Item {
    id: heading

    property string text
    property bool first: false

    width: Look.boxWidth
    height: (first ? Look.headingTop : Look.headingAbove) + label.implicitHeight

    Label {
        id: label
        x: Look.boxPadding
        anchors.bottom: parent.bottom
        text: heading.text
        style: Theme.text.headline
        font.weight: 700
    }
}
