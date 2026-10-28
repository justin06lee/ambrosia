import QtQuick
import Ambrosia
import Settings

// General › About: the computer's picture, model and maker; its name (which
// can be changed here), processor, memory and graphics; the system and its
// version; the displays; the system volume; and System Report…, as System
// Settings lays them out. A Mac's serial number and AppleCare have no
// counterpart and are left out.
Page {
    id: page

    Component.onCompleted: About.refresh()

    // The computer, centred: its picture 10 under the toolbar, the model
    // under it and the maker under that.
    Item {
        width: Look.boxWidth
        height: 197

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            width: 128
            height: 128
            sourceSize: Qt.size(256, 256)
            source: "qrc:/qt/qml/Settings/art/" + (About.laptop ? "laptop" : "desktop") + ".svg"
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 140
            text: About.model
            style: Theme.text.largeTitle
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 173
            visible: About.maker !== ""
            text: About.maker
            style: Theme.text.caption
            color: Theme.color.label.secondary
        }
    }

    Box {
        FormRow {
            label: "Name"
            NameField {
                width: 360
                value: About.computerName
                onCommitted: (text) => About.setComputerName(text)
            }
        }
        FormRow { label: "Processor"; value: About.chip; visible: About.chip !== "" }
        FormRow { label: "Memory"; value: About.memory; visible: About.memory !== "" }
        FormRow {
            label: "Graphics"
            value: About.graphics.join(", ")
            visible: About.graphics.length > 0
        }
    }

    SectionHeading { text: About.systemName }
    Box {
        Item {
            width: parent.width
            height: 52
            Image {
                x: Look.boxPadding
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                sourceSize: Qt.size(64, 64)
                // The system's logo, which ambrosia-desktop installs.
                source: "file:///usr/share/icons/hicolor/scalable/apps/ambrosia-logo.svg"
            }
            Label {
                x: Look.boxPadding + 42
                anchors.verticalCenter: parent.verticalCenter
                text: About.systemName
            }
            Label {
                x: parent.width - Look.boxPadding - width
                anchors.verticalCenter: parent.verticalCenter
                visible: About.systemVersion !== ""
                text: "Version " + About.systemVersion
                color: Theme.color.label.secondary
            }
        }
    }

    SectionHeading { text: "Displays" }
    Box {
        Repeater {
            model: About.displays
            Item {
                id: display
                required property var modelData
                width: parent.width
                height: 52
                Image {
                    x: Look.boxPadding
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    sourceSize: Qt.size(64, 64)
                    source: "qrc:/qt/qml/Settings/art/" + (display.modelData.name === "Built-in Display" ? "laptop" : "desktop") + ".svg"
                }
                Label {
                    x: Look.boxPadding + 42
                    width: detail.x - x - 12
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: display.modelData.name
                }
                Label {
                    id: detail
                    x: parent.width - Look.boxPadding - width
                    anchors.verticalCenter: parent.verticalCenter
                    text: display.modelData.detail
                    color: Theme.color.label.secondary
                }
            }
        }
        FormRow {
            visible: Panes.available(Panes.find("displays"))
            PushButton {
                text: "Display Settings…"
                onClicked: page.settings.choose("displays")
            }
        }
    }

    SectionHeading { text: "Storage" }
    Box {
        Item {
            width: parent.width
            height: 52
            Image {
                x: Look.boxPadding
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32
                sourceSize: Qt.size(64, 64)
                source: "qrc:/qt/qml/Settings/art/drive.svg"
            }
            Label {
                x: Look.boxPadding + 42
                anchors.verticalCenter: parent.verticalCenter
                text: About.volumeName
            }
            Label {
                x: parent.width - Look.boxPadding - width
                anchors.verticalCenter: parent.verticalCenter
                text: About.volumeSpace
                color: Theme.color.label.secondary
            }
        }
    }

    // KDE's Info Center holds what a Mac's System Report does.
    Item {
        width: Look.boxWidth
        height: Look.popupHeight + Look.boxGap
        visible: App.has("kinfocenter")
        PushButton {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Look.boxGap
            text: "System Report…"
            onClicked: App.run("kinfocenter")
        }
    }
}
