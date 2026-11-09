import QtQuick
import Ambrosia
import Settings

// Menu Bar, as System Settings lays it out: hiding, its background, and the
// controls it shows, which the shell draws from what's here. Left out: On
// Desktop Only (no desktop of icons to tell apart), Recent documents (no such
// menu), Add Controls… and Allow in the Menu Bar (apps' tray icons aren't on
// our bar), Siri, AirDrop and the like, Display and Fast User Switching (no
// item of ours), Reset Control Center… and the help button.
Page {
    id: page

    readonly property var hidden: Preferences.all.menuBarHidden ?? ["bluetooth"]
    readonly property var always: Preferences.all.menuBarAlways ?? []

    function toggled(list, key, on) {
        const others = list.filter(each => each !== key);
        return on ? others.concat([key]) : others;
    }

    component Control: Item {
        id: control
        property string key
        property string text
        property string glyph
        property string tint: "blue"
        // Shows while it has something to say, or always.
        property bool idles: false
        width: parent.width
        height: 43
        CheckBox {
            x: 13.5
            anchors.verticalCenter: parent.verticalCenter
            checked: !page.hidden.includes(control.key)
            onToggled: Preferences.set("menuBarHidden", page.toggled(page.hidden, control.key, checked))
        }
        PaneIcon {
            x: 37
            anchors.verticalCenter: parent.verticalCenter
            size: 22
            glyph: control.glyph
            tint: control.tint
        }
        Label {
            x: 65
            anchors.verticalCenter: parent.verticalCenter
            text: control.text
        }
        PopUpButton {
            visible: control.idles
            x: parent.width - Look.boxPadding - width
            anchors.verticalCenter: parent.verticalCenter
            items: [
                { text: qsTr("Show When Active"), value: false },
                { text: qsTr("Always Show"), value: true },
            ]
            current: page.always.includes(control.key)
            onChosen: (value) => Preferences.set("menuBarAlways", page.toggled(page.always, control.key, value))
        }
    }

    Box {
        FormRow {
            label: qsTr("Automatically hide and show the menu bar")
            PopUpButton {
                items: [
                    { text: qsTr("Always"), value: "always" },
                    { text: qsTr("In Full Screen Only"), value: "fullscreen" },
                    { text: qsTr("Never"), value: "never" },
                ]
                current: Preferences.all.menuBarAutohide ?? "fullscreen"
                onChosen: (value) => Preferences.set("menuBarAutohide", value)
            }
        }
        FormRow {
            label: qsTr("Show menu bar background")
            Switch {
                checked: Preferences.all.menuBarBackground ?? true
                onToggled: Preferences.set("menuBarBackground", !checked)
            }
        }
    }

    SectionHeading { text: qsTr("Menu Bar Controls") }
    Box {
        Item {
            width: parent.width
            height: 43
            PaneIcon {
                x: 37
                anchors.verticalCenter: parent.verticalCenter
                size: 22
                glyph: "datetime"
                tint: "gray"
            }
            Label {
                x: 65
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Clock")
            }
            PushButton {
                x: parent.width - Look.boxPadding - width
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Clock Options…")
                onClicked: clock.open = true
            }
        }
        Control { key: "search"; text: qsTr("Spotlight"); glyph: "spotlight" }
        Control { key: "wifi"; text: qsTr("Wi‑Fi"); glyph: "wifi" }
        Control { key: "bluetooth"; text: qsTr("Bluetooth"); glyph: "bluetooth" }
        Control { key: "battery"; text: qsTr("Battery"); glyph: "battery"; tint: "green"; visible: App.hasBattery }
        Control { key: "focus"; text: qsTr("Focus"); glyph: "focus"; tint: "indigo"; idles: true }
        Control { key: "sound"; text: qsTr("Sound"); glyph: "sound"; tint: "pink"; idles: true }
        Control { key: "nowplaying"; text: qsTr("Now Playing"); glyph: "play"; tint: "pink"; idles: true }
    }

    ClockOptionsSheet {
        id: clock
        settings: page.settings
    }
}
