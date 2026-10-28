import QtQuick
import Ambrosia
import Settings

// A pane's page: its boxes and headings in a column 20 in from either side,
// 10 apart, scrolling under the toolbar with an overlay scroll bar while it
// moves.
Flickable {
    id: page

    required property var settings
    default property alias content: column.data
    // The header box the pane opens with, if any: while its own title is in
    // view the toolbar leaves the pane's name out, as System Settings does.
    property Item header: null
    readonly property bool showsTitle: !header || contentY > header.y + Look.headerTitleY

    contentWidth: width
    contentHeight: column.implicitHeight + Look.margin
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: column
        x: Look.margin
        width: Look.boxWidth
        spacing: Look.boxGap
    }

    Rectangle {
        parent: page
        visible: page.contentHeight > page.height
        x: page.width - 9
        y: 3 + page.visibleArea.yPosition * (page.height - 6)
        width: 6
        height: page.visibleArea.heightRatio * (page.height - 6)
        radius: 3
        color: Theme.dark ? "#73ffffff" : "#59000000"
        opacity: page.moving ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fade.base } }
    }
}
