import QtQuick
import Ambrosia
import Settings

// Printers & Scanners, after macOS 26's pane: the default printer and paper
// size, the printers (CUPS's own and those it finds on the network, which
// print without being added), each with a sheet, and adding one by its
// address. Left out: scanners and faxes, a printer's queue window, Options &
// Supplies… and sharing a printer (nothing here does them), and choosing a
// driver (only driverless printers are added).
Page {
    id: page

    Component.onCompleted: Printers.read()
    Timer {
        interval: 5000
        running: page.visible
        repeat: true
        onTriggered: Printers.read()
    }

    // The printer whose sheet is open.
    property string shownName: ""
    readonly property var shown: Printers.printers.find(each => each.name === shownName) ?? null
    function status(printer) {
        const state = printer.state === "printing" ? (printer.jobs > 1 ? qsTr("Printing, %1 jobs").arg(printer.jobs) : qsTr("Printing"))
            : printer.state === "stopped" ? qsTr("Paused")
            : printer.state === "nearby" ? qsTr("On the network") : qsTr("Idle");
        return printer.isDefault ? qsTr("%1, Default").arg(state) : state;
    }

    Box {
        visible: Printers.printers.length > 0
        FormRow {
            label: qsTr("Default printer")
            PopUpButton {
                items: [{ text: qsTr("Last Printer Used"), value: "" }].concat(Printers.printers.map(each => ({ text: each.title, value: each.name })))
                current: Printers.defaultPrinter
                onChosen: (value) => Printers.defaultPrinter = value
            }
        }
        FormRow {
            label: qsTr("Default paper size")
            PopUpButton {
                items: Printers.papers
                current: Printers.paper
                onChosen: (value) => Printers.paper = value
            }
        }
    }
    Box {
        Item {
            visible: Printers.printers.length === 0
            width: parent.width
            height: 34
            Label {
                anchors.centerIn: parent
                text: Printers.running ? qsTr("No Printers") : qsTr("Printing isn't running on this computer")
                color: Theme.color.label.secondary
            }
        }
        Repeater {
            model: Printers.printers
            Item {
                id: row
                required property var modelData
                width: parent ? parent.width : Look.boxWidth
                height: 52
                PaneIcon {
                    x: Look.boxPadding
                    anchors.verticalCenter: parent.verticalCenter
                    size: 32
                    glyph: "printer"
                    tint: "gray"
                }
                Column {
                    x: 50
                    width: info.x - x - 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Label {
                        width: parent.width
                        text: row.modelData.title
                        elide: Text.ElideRight
                    }
                    Label {
                        width: parent.width
                        text: page.status(row.modelData)
                        style: Theme.text.caption
                        color: Theme.color.label.secondary
                        elide: Text.ElideRight
                    }
                }
                InfoButton {
                    id: info
                    x: row.width - Look.boxPadding - width - 2
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: {
                        page.shownName = row.modelData.name;
                        printerSheet.open = true;
                    }
                }
            }
        }
    }
    Item {
        width: parent.width
        height: Look.popupHeight
        PushButton {
            anchors.right: parent.right
            enabled: Printers.running
            text: qsTr("Add Printer…")
            onClicked: addSheet.show()
        }
    }

    // A printer's sheet: what and where it is, a test page, and removing it
    // if it's a queue of this computer's.
    Sheet {
        id: printerSheet
        settings: page.settings
        sheetWidth: 440
        below: 24
        onAccepted: close()
        Row {
            spacing: 14
            PaneIcon {
                size: 52
                glyph: "printer"
                tint: "gray"
            }
            Column {
                width: 440 - 2 * Look.margin - 66
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Label {
                    width: parent.width
                    text: page.shown?.title ?? ""
                    style: Theme.text.title3
                    elide: Text.ElideRight
                }
                Label {
                    text: page.shown ? page.status(page.shown) : ""
                    color: Theme.color.label.secondary
                }
            }
        }
        Box {
            width: parent.width
            FormRow {
                visible: (page.shown?.model ?? "") !== ""
                label: qsTr("Kind")
                value: page.shown?.model ?? ""
            }
            FormRow {
                visible: (page.shown?.location ?? "") !== ""
                label: qsTr("Location")
                value: page.shown?.location ?? ""
            }
            FormRow {
                visible: (page.shown?.address ?? "") !== ""
                label: qsTr("Address")
                value: page.shown?.address ?? ""
            }
            FormRow {
                label: qsTr("Queue name")
                value: page.shown?.name ?? ""
            }
        }
        leading: [
            PushButton {
                visible: page.shown?.added ?? false
                text: qsTr("Remove Printer…")
                onClicked: removeSheet.open = true
            }
        ]
        trailing: [
            PushButton {
                text: qsTr("Print Test Page")
                onClicked: Printers.printTestPage(page.shownName)
            },
            PushButton {
                text: qsTr("Done")
                primary: true
                minimumWidth: 70
                onClicked: printerSheet.accepted()
            }
        ]
    }

    Sheet {
        id: removeSheet
        settings: page.settings
        sheetWidth: 400
        below: 24
        onAccepted: {
            Printers.remove(page.shownName);
            close();
            printerSheet.close();
        }
        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            font.weight: 600
            text: qsTr("Remove the printer “%1”?").arg(page.shown?.title ?? "")
        }
        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            color: Theme.color.label.secondary
            text: qsTr("Its waiting jobs are canceled. You can add it again later.")
        }
        trailing: [
            PushButton {
                text: qsTr("Cancel")
                minimumWidth: 88
                onClicked: removeSheet.close()
            },
            PushButton {
                text: qsTr("Remove Printer")
                primary: true
                minimumWidth: 88
                onClicked: removeSheet.accepted()
            }
        ]
    }

    // Adding a printer the network search didn't find, by its address.
    Sheet {
        id: addSheet
        settings: page.settings
        sheetWidth: 460
        below: 24

        property string problem: ""
        // The name follows the address until it's typed in.
        property bool nameTyped: false
        readonly property bool ready: addressField.text.trim() !== "" && !Printers.adding
        function show() {
            addressField.text = "";
            nameField.text = "";
            locationField.text = "";
            nameTyped = false;
            problem = "";
            open = true;
            addressField.forceActiveFocus();
        }
        onAccepted: {
            if (!ready)
                return;
            problem = "";
            Printers.add(addressField.text, nameField.text, locationField.text);
        }
        Connections {
            target: Printers
            function onAddDone(ok, message) {
                if (!addSheet.open)
                    return;
                if (ok)
                    addSheet.close();
                else
                    addSheet.problem = message;
            }
        }

        Label {
            text: qsTr("Add Printer")
            font.weight: 600
        }
        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            style: Theme.text.caption
            color: Theme.color.label.secondary
            text: qsTr("Printers on your network appear in the list by themselves. To add another, enter its host name or IP address.")
        }
        Box {
            width: parent.width
            FormRow {
                label: qsTr("Address")
                NameField {
                    id: addressField
                    width: 240
                    ring: false
                    activeFocusOnTab: true
                    placeholder: qsTr("Host name or IP address")
                    Accessible.name: qsTr("Address")
                    onTextChanged: if (!addSheet.nameTyped) nameField.text = text.trim().replace(/^[a-z]+:\/\//, "").replace(/[/:].*$/, "")
                }
            }
            FormRow {
                label: qsTr("Name")
                NameField {
                    id: nameField
                    width: 240
                    ring: false
                    activeFocusOnTab: true
                    Accessible.name: qsTr("Name")
                    onTextEdited: addSheet.nameTyped = true
                }
            }
            FormRow {
                label: qsTr("Location")
                NameField {
                    id: locationField
                    width: 240
                    ring: false
                    activeFocusOnTab: true
                    Accessible.name: qsTr("Location")
                }
            }
        }
        Label {
            width: parent.width
            visible: addSheet.problem !== ""
            wrapMode: Text.WordWrap
            style: Theme.text.caption
            color: Theme.color.palette.red
            text: addSheet.problem
        }
        leading: [
            Spinner {
                visible: Printers.adding
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            }
        ]
        trailing: [
            PushButton {
                text: qsTr("Cancel")
                enabled: !Printers.adding
                onClicked: addSheet.close()
            },
            PushButton {
                text: qsTr("Add")
                primary: true
                minimumWidth: 70
                enabled: addSheet.ready
                onClicked: addSheet.accepted()
            }
        ]
    }
}
