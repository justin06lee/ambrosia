import Quickshell.Widgets
import QtQuick
import Ambrosia

// One notification on glass, as a banner or in the notification center: its
// app's icon (or its own picture), the app's name and when it came, what it
// says, and its actions other than the default one as buttons. A click runs
// the default; on hover a close button shows at the top left, as on a Mac.
// Without previews (Settings) it says only that there's one.
Item {
    id: card

    property string appName
    property string iconSource
    property string summary
    property string body
    // When it came (ms since the epoch), against `now`; 0 is "now".
    property real time: 0
    property date now: new Date()
    property var buttons: []
    property bool closable: true
    // Drawn behind a stack: no text, only the glass.
    property bool blank: false
    readonly property alias hovered: area.containsMouse

    signal activated
    signal closeClicked

    readonly property int bodyHeight: Math.max(row.implicitHeight + 2 * Theme.space.s3, 64)
    implicitWidth: 344
    implicitHeight: bodyHeight + (buttons.length && !blank ? actions.height + Theme.space.s3 : 0)

    function ago(time, now) {
        if (!time) return "now";
        const minutes = Math.floor((now.getTime() - time) / 60000);
        if (minutes < 1) return "now";
        if (minutes < 60) return `${minutes}m ago`;
        const then = new Date(time);
        const days = Math.round((new Date(now.getFullYear(), now.getMonth(), now.getDate())
            - new Date(then.getFullYear(), then.getMonth(), then.getDate())) / 86400000);
        if (days === 0) return `${Math.floor(minutes / 60)}h ago`;
        if (days === 1) return "Yesterday";
        if (days < 7) return Qt.formatDate(then, "dddd");
        return Qt.formatDate(then, "MMM d");
    }

    Glass {
        anchors.fill: parent
        tint: Theme.color.material.regular.tint
        radius: Theme.radius.panel
        shadow: Theme.color.shadow.panel
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: card.activated()
    }

    Row {
        id: row
        visible: !card.blank
        x: Theme.space.s3
        y: Theme.space.s3
        width: parent.width - Theme.space.s3 - Theme.space.s4
        spacing: Theme.space.s3

        IconImage {
            implicitSize: 36
            source: card.iconSource
        }

        Column {
            width: row.width - 36 - row.spacing

            Item {
                width: parent.width
                height: appLabel.implicitHeight

                Label {
                    id: appLabel
                    width: parent.width - timeLabel.implicitWidth - Theme.space.s2
                    text: card.appName.toUpperCase()
                    style: Theme.text.footnote
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0.4
                    color: Theme.color.label.secondary
                    elide: Text.ElideRight
                }
                Label {
                    id: timeLabel
                    anchors.right: parent.right
                    text: card.ago(card.time, card.now)
                    style: Theme.text.caption
                    color: Theme.color.label.secondary
                }
            }
            Label {
                width: parent.width
                text: Settings.notificationPreviews ? card.summary : "Notification"
                style: Theme.text.headline
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }
            Label {
                width: parent.width
                visible: text !== ""
                text: Settings.notificationPreviews ? card.body : ""
                color: Theme.color.label.secondary
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                textFormat: Text.StyledText
            }
        }
    }

    Row {
        id: actions
        visible: card.buttons.length > 0 && !card.blank
        x: Theme.space.s3
        y: card.bodyHeight
        width: parent.width - 2 * Theme.space.s3
        spacing: Theme.space.s2

        Repeater {
            model: card.buttons
            PushButton {
                required property var modelData
                width: (actions.width - (card.buttons.length - 1) * actions.spacing) / card.buttons.length
                text: modelData.text
                onClicked: modelData.invoke()
            }
        }
    }

    // Close: shown on hover, top left, as on a Mac.
    Rectangle {
        visible: card.closable && !card.blank && (area.containsMouse || closeArea.containsMouse)
        x: -6
        y: -6
        width: 18
        height: 18
        radius: 9
        color: Theme.color.bg.elevated
        border.width: 0.5
        border.color: Theme.color.glass.edge

        Label {
            anchors.centerIn: parent
            text: "×"
            style: Theme.text.callout
            color: Theme.color.label.secondary
        }
        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: card.closeClicked()
        }
    }
}
