import QtQuick
import Ambrosia
import Settings

// Desktop & Dock's Hot Corners…: what pushing the pointer into each corner of
// the screen does. Our own layout after the Mac's, which wasn't photographed;
// its other actions (Launchpad, Quick Note…) have nothing on our side.
Sheet {
    id: sheet

    sheetWidth: 470
    below: 24
    onAccepted: close()

    readonly property var actions: [
        { text: "–", value: "none" },
        { text: qsTr("Mission Control"), value: "overview" },
        { text: qsTr("Application Windows"), value: "windows" },
        { text: qsTr("Desktop"), value: "desktop" },
        { text: qsTr("Lock Screen"), value: "lock" },
    ]
    // Read again each time it opens; the choices then set them.
    property int reads: 0
    onOpenChanged: reads++

    component Corner: PopUpButton {
        required property string corner
        items: sheet.actions
        current: { sheet.reads; return Windowing.hotCorner(corner); }
        onChosen: (value) => { Windowing.setHotCorner(corner, value); sheet.reads++; }
    }

    Box {
        width: parent.width
        Item {
            width: parent.width
            height: 164
            Corner {
                corner: "TopLeft"
                x: 14
                y: 14
            }
            Corner {
                corner: "TopRight"
                x: parent.width - 14 - width
                y: 14
            }
            Corner {
                corner: "BottomLeft"
                x: 14
                y: parent.height - 14 - height
            }
            Corner {
                corner: "BottomRight"
                x: parent.width - 14 - width
                y: parent.height - 14 - height
            }
            // The screen, its corners between them.
            Rectangle {
                anchors.centerIn: parent
                width: 120
                height: 76
                radius: 6
                color: Look.face
                border.width: 1
                border.color: Look.hairline
            }
        }
    }

    trailing: PushButton {
        text: qsTr("Done")
        primary: true
        onClicked: sheet.close()
    }
}
