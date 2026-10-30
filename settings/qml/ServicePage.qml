import QtQuick
import Ambrosia
import Settings

// A network service's own page, as System Settings has it: its icon, name
// and state with Details…, then Delete Service… and Make Inactive under the
// box. The service is the window's anchor (a device); its settings are its
// saved connection's. Left out: the help button.
Page {
    id: page

    readonly property var service: Network.connected.concat(Network.others).find(s => s.id === page.settings.anchor) ?? ({})
    readonly property bool inactive: service.state === "inactive"
    readonly property bool configured: (service.uuid ?? "") !== ""

    Box {
        ServiceRow {
            height: 56
            settings: page.settings
            service: page.service
            topInset: 2
            plain: true
            PushButton {
                x: parent.width - Look.boxPadding - width
                y: 10
                width: 76
                enabled: page.configured
                text: qsTr("Details…")
                onClicked: detailsSheet.show(page.service.uuid)
            }
        }
    }
    // 20 under the box, as a page's foot.
    Row {
        topPadding: Look.boxGap
        spacing: 10
        PushButton {
            visible: page.configured
            text: qsTr("Delete Service…")
            onClicked: deleteSheet.open = true
        }
        PushButton {
            visible: page.configured
            text: page.inactive ? qsTr("Make Active") : qsTr("Make Inactive")
            onClicked: Network.setActive(page.service.id, page.inactive)
        }
    }

    DetailsSheet {
        id: detailsSheet
        settings: page.settings
        source: Network
        name: page.service.name ?? ""
        glyph: "ethernet"
        tint: "gray"
    }
    // Asks first: what's set for it is gone. Not photographed on the Mac.
    Sheet {
        id: deleteSheet
        settings: page.settings
        sheetWidth: 400
        onAccepted: {
            Network.deleteService(page.service.uuid);
            close();
        }

        Label {
            width: parent.width
            text: qsTr("Delete “%1”?").arg(page.service.name ?? "")
            style: Theme.text.headline
            wrapMode: Text.Wrap
        }
        Label {
            width: parent.width
            text: qsTr("Its settings will be removed. It stays in the list, not configured.")
            color: Theme.color.label.secondary
            wrapMode: Text.Wrap
        }

        trailing: [
            PushButton {
                id: cancelButton
                text: qsTr("Cancel")
                onClicked: deleteSheet.close()
            },
            PushButton {
                text: qsTr("Delete")
                minimumWidth: cancelButton.implicitWidth
                primary: true
                onClicked: deleteSheet.accepted()
            }
        ]
    }
}
