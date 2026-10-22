import QtQuick
import Ambrosia

// One of Get Info's sections: a rule, then its title with a chevron (a
// click on either opens or closes it), then what it holds while open.
Column {
    id: section

    property string title
    property bool open: true
    default property alias content: body.data

    Rectangle {
        width: section.width
        height: 1
        color: Finder.infoRule
    }
    Item {
        width: section.width
        height: 19
        Glyph {
            x: 5.5
            anchors.verticalCenter: parent.verticalCenter
            name: "disclosure"
            size: 12
            rotation: section.open ? 90 : 0
            color: Theme.color.label.secondary
            Behavior on rotation { NumberAnimation { duration: 120 } }
        }
        Label {
            x: 21.5
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 12
            text: section.title
        }
        TapHandler { onTapped: section.open = !section.open }
    }
    Column {
        id: body
        visible: section.open
        width: section.width
        topPadding: 6
        bottomPadding: 7
    }
}
