import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Ambrosia
import Settings

// A sheet over the window, as System Settings shows them (Bluetooth's ⓘ,
// Wi-Fi's Details…): the window dimmed under it, the sheet centred on it
// with 24 corners, a dark outline and a lighter rim inside; its boxes 20
// in, and its buttons along the foot under a rule, the default one on the
// right. Escape closes it, Return presses the default button. One with a
// sidebar of its own (Wi-Fi's Details…) has it inset 8 on the left, pageX
// wide with the inset, and its page scrolling in bodyHeight over the
// buttons.
Item {
    id: sheet

    // The window it covers (a page's settings).
    required property var settings
    property bool open: false
    property real sheetWidth: 490
    property real pageX: 0
    property real bodyHeight: 0
    property alias side: sideArea.data
    default property alias content: column.data
    // Buttons on the left of the foot, and on the right (the default last).
    property alias leading: leadingRow.data
    property alias trailing: trailingRow.data
    signal accepted()

    function close() { open = false; }
    onOpenChanged: settings.sheetsOpen += open ? 1 : -1
    Component.onDestruction: if (open) settings.sheetsOpen -= 1

    parent: settings.contentItem
    anchors.fill: parent
    z: 100
    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.fade.fast } }

    // Escape puts back a field being typed in (a NameField's revert) and
    // closes; Return keeps what's typed, then presses the default button.
    Shortcut {
        sequence: "Esc"
        enabled: sheet.open
        onActivated: {
            const field = sheet.settings.activeFocusItem;
            if (field && typeof field.revert === "function")
                field.revert();
            sheet.close();
        }
    }
    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: sheet.open
        onActivated: {
            panel.forceActiveFocus();
            sheet.accepted();
        }
    }

    // The window dimmed round the sidebar, which floats above it faded
    // (Sidebar.qml); the window under it takes no clicks while it's up.
    Shape {
        anchors.fill: parent
        opacity: Theme.dark ? 0.3 : 0.12
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: "black"
            strokeWidth: -1
            fillRule: ShapePath.OddEvenFill
            PathRectangle { width: sheet.width; height: sheet.height; radius: Look.windowRadius }
            PathRectangle {
                x: Look.sidebarInset
                y: Look.sidebarInset
                width: Look.sidebarWidth
                height: sheet.height - 2 * Look.sidebarInset
                radius: Look.sidebarRadius
            }
        }
    }
    MouseArea {
        x: Look.sidebarInset + Look.sidebarWidth
        width: parent.width - x
        height: parent.height
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onWheel: (wheel) => wheel.accepted = true
    }

    Rectangle {
        id: panel
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        width: sheet.sheetWidth
        height: body.height + 1 + 2 * Look.margin + Look.popupHeight
        radius: 24
        color: Look.sheet
        border.width: 0.5
        border.color: Look.sheetOutline
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "black"
            shadowOpacity: Theme.dark ? 0.6 : 0.25
            shadowBlur: 1
            shadowVerticalOffset: 10
            blurMax: 48
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 0.5
            radius: 23.5
            color: "transparent"
            border.width: 1
            border.color: Look.sheetRim
        }
        Rectangle {
            id: sideArea
            visible: sheet.pageX > 0
            x: Look.sidebarInset
            y: Look.sidebarInset
            width: sheet.pageX - Look.sidebarInset
            height: parent.height - 2 * Look.sidebarInset
            radius: parent.radius - Look.sidebarInset
            color: Look.sidebar
            border.width: 0.5
            border.color: Look.sidebarRim
        }
        Flickable {
            id: body
            x: sheet.pageX
            width: parent.width - x
            height: sheet.bodyHeight > 0 ? sheet.bodyHeight : contentHeight
            contentHeight: column.height + 2 * Look.margin
            clip: sheet.bodyHeight > 0
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: column
                x: Look.margin
                y: Look.margin
                width: body.width - 2 * Look.margin
                spacing: Look.boxGap
            }
        }
        Rectangle {
            id: rule
            x: sheet.pageX
            y: body.height
            width: parent.width - x
            height: 1
            color: Look.sheetRule
        }
        Row {
            id: leadingRow
            x: sheet.pageX + Look.margin
            y: rule.y + 1 + Look.margin
            spacing: 8
        }
        Row {
            id: trailingRow
            x: parent.width - Look.margin - width
            y: leadingRow.y
            spacing: 8
        }
    }
}
