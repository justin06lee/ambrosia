import QtQuick
import Ambrosia
import Settings

// Wallpaper, as System Settings lays it out: what's on the desktop and how
// it fits, then what to choose from, scrolling under a rule. The shell draws
// it. Left out: Show on all Spaces (the one wallpaper is on every desktop),
// Screen Saver…, Clock Appearance…, Apple's pictures and aerials, Shuffle,
// Show All (a section wraps instead) and the help button.
Item {
    id: root

    required property var settings
    readonly property bool showsTitle: true
    readonly property string current: Preferences.wallpaper
    readonly property bool isColor: current.startsWith("#")
    readonly property bool isNectar: !isColor && !current.startsWith("/")
    readonly property string folder: "file://" + Preferences.wallpaperFolder()
    readonly property var colors: [
        { color: "#000000", name: qsTr("Black") },
        { color: "#6867aa", name: qsTr("Blue Violet") },
        { color: "#51accc", name: qsTr("Cyan") },
        { color: "#d1747b", name: qsTr("Dusty Rose") },
        { color: "#4553ce", name: qsTr("Electric Blue") },
        { color: "#f7dccc", name: qsTr("Gold") },
    ]
    readonly property string currentName: {
        if (isNectar)
            return qsTr("Nectar");
        if (isColor)
            return colors.find(each => each.color === current)?.name ?? qsTr("Custom Color");
        return current.split("/").pop().replace(/\.[^.]*$/, "");
    }

    function fileName(path) {
        return path.split("/").pop().replace(/\.[^.]*$/, "");
    }

    WallpaperPicture {
        x: 16
        y: 16
        width: 160
        height: 100
        radius: 7
        color: root.isColor ? root.current : "black"
        source: root.isColor ? "" : root.isNectar
            ? root.folder + (Theme.dark ? "/nectar-night.png" : "/nectar-day.png")
            : Preferences.pictureUrl(root.current)
        fillMode: ({
            fit: Image.PreserveAspectFit,
            stretch: Image.Stretch,
            center: Image.Pad,
            tile: Image.Tile,
        })[Preferences.wallpaperFit] ?? Image.PreserveAspectCrop
    }

    Rectangle {
        x: 186
        y: 16
        width: 298
        height: 37
        radius: Look.boxRadius
        color: Look.box
        Label {
            x: Look.boxPadding
            width: 150
            anchors.verticalCenter: parent.verticalCenter
            text: root.currentName
            elide: Text.ElideMiddle
        }
        PopUpButton {
            visible: !root.isColor
            x: parent.width - Look.boxPadding - width
            anchors.verticalCenter: parent.verticalCenter
            items: [
                { text: qsTr("Fill Screen"), value: "fill" },
                { text: qsTr("Fit to Screen"), value: "fit" },
                { text: qsTr("Stretch to Fill Screen"), value: "stretch" },
                { text: qsTr("Center"), value: "center" },
                { text: qsTr("Tile"), value: "tile" },
            ]
            current: Preferences.wallpaperFit
            onChosen: (value) => Preferences.wallpaperFit = value
        }
    }

    Rectangle {
        y: 141
        width: parent.width
        height: 1
        color: Look.bandRule
    }

    Page {
        settings: root.settings
        y: 142
        width: parent.width
        height: parent.height - y

        Column {
            topPadding: 20

            Label {
                height: 25.5
                text: qsTr("Dynamic Wallpapers")
                style: Theme.text.headline
                font.weight: 700
            }
            WallpaperTile {
                source: root.folder + "/nectar-day.png"
                second: root.folder + "/nectar-night.png"
                name: qsTr("Nectar")
                caption: true
                dynamic: true
                chosen: root.isNectar
                onClicked: Preferences.wallpaper = "nectar"
            }
            Item { width: 1; height: 20 }

            Label {
                height: 25.5
                text: qsTr("Your Photos")
                style: Theme.text.headline
                font.weight: 700
            }
            Flow {
                width: Look.boxWidth + 1
                spacing: 9
                Rectangle {
                    width: 108.5
                    height: 72
                    radius: Look.tileRadius
                    color: Look.box
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Add Photo…")
                    Glyph {
                        x: 54.25 - 18
                        y: 8
                        size: 36
                        name: "addPhoto"
                        color: Theme.color.label.tertiary
                    }
                    Rectangle {
                        x: 68
                        y: 25
                        width: 14
                        height: 14
                        radius: 7
                        color: Theme.color.label.tertiary
                        Glyph {
                            anchors.centerIn: parent
                            size: 12
                            name: "plus"
                            color: Look.box
                        }
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 49
                        text: qsTr("Add Photo…")
                        style: Theme.text.footnote
                        color: Theme.color.label.tertiary
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Preferences.addWallpaperPicture()
                    }
                }
                Repeater {
                    model: Preferences.wallpaperRecent
                    WallpaperTile {
                        required property string modelData
                        source: Preferences.pictureUrl(modelData)
                        name: root.fileName(modelData)
                        chosen: root.current === modelData
                        onClicked: Preferences.wallpaper = modelData
                    }
                }
            }
            Item { width: 1; height: 29 }

            Label {
                height: 26
                text: qsTr("Colors")
                style: Theme.text.headline
                font.weight: 700
            }
            Row {
                spacing: 10
                Rectangle {
                    width: 48.5
                    height: 48.5
                    radius: width / 2
                    color: Look.face
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Custom Color")
                    Glyph {
                        anchors.centerIn: parent
                        size: 28
                        name: "plus"
                        color: Theme.color.label.secondary
                    }
                    Rectangle {
                        visible: root.isColor && !root.colors.some(each => each.color === root.current)
                        anchors.fill: parent
                        radius: width / 2
                        color: root.current
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Preferences.chooseWallpaperColor()
                    }
                }
                Repeater {
                    model: root.colors
                    WallpaperTile {
                        required property var modelData
                        round: true
                        color: modelData.color
                        name: modelData.name
                        chosen: root.current === modelData.color
                        onClicked: Preferences.wallpaper = modelData.color
                    }
                }
            }
        }
    }
}
