import QtQuick
import Ambrosia

// A Dock stack, opened: the folder's newest things as a grid of icons with
// their names, on glass, and a button that opens the folder itself. Only the
// picture: Stack.qml reads the folder and opens what is clicked.
Item {
    id: grid

    // Rows of { name, icon: a picture's URL }.
    property var items: []
    // Still reading the folder: say nothing about it being empty yet.
    property bool loading: false
    signal opened(int index)
    signal folderOpened

    readonly property int columns: Theme.size.stack.columns
    readonly property int cell: Theme.size.stack.cell
    readonly property int pad: Theme.size.stack.padding
    // An icon, and two lines of name under it.
    readonly property int cellHeight: Theme.size.stack.icon + Theme.space.s2 + 2 * Theme.text.caption.line + Theme.space.s3
    readonly property int shownRows: Math.max(1, Math.min(Theme.size.stack.rows, Math.ceil(items.length / columns)))

    implicitWidth: columns * cell + 2 * pad
    implicitHeight: pad + shownRows * cellHeight + Theme.space.s2 + button.height + pad

    Glass {
        anchors.fill: parent
        tint: Theme.color.material.thick.tint
        radius: Theme.radius.panel
        shadow: Theme.color.shadow.panel
    }

    // Clicks between the icons stay here.
    MouseArea {
        anchors.fill: parent
    }

    GridView {
        id: view
        x: grid.pad
        y: grid.pad
        width: grid.columns * grid.cell
        height: grid.shownRows * grid.cellHeight
        cellWidth: grid.cell
        cellHeight: grid.cellHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: grid.items

        delegate: Item {
            id: thing

            required property int index
            required property var modelData

            width: grid.cell
            height: grid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: Theme.radius.control
                color: area.pressed ? Theme.color.fill.primary : Theme.color.fill.secondary
                visible: area.containsMouse
            }

            Image {
                id: art
                anchors.horizontalCenter: parent.horizontalCenter
                y: Theme.space.s2
                width: Theme.size.stack.icon
                height: Theme.size.stack.icon
                source: thing.modelData.icon
                sourceSize: Qt.size(2 * width, 2 * height)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                y: art.y + art.height + Theme.space.s1
                width: parent.width - Theme.space.s2
                height: 2 * Theme.text.caption.line
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignTop
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 2
                elide: Text.ElideRight
                lineHeight: Theme.text.caption.line
                lineHeightMode: Text.FixedHeight
                text: thing.modelData.name
                style: Theme.text.caption
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                onClicked: grid.opened(thing.index)
            }
        }
    }

    Label {
        anchors.centerIn: view
        visible: grid.items.length === 0 && !grid.loading
        text: "No Items"
        color: Theme.color.label.secondary
    }

    PushButton {
        id: button
        anchors.horizontalCenter: parent.horizontalCenter
        y: view.y + view.height + Theme.space.s2
        text: "Open in Files"
        onClicked: grid.folderOpened()
    }
}
