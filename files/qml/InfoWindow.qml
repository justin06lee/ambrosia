import QtQuick
import QtQuick.Window
import Ambrosia
import Files

// Get Info (⌘I): one item's window. Its name, size and date at the top,
// then Finder's sections, each opened and closed by its title: General,
// More Info, Name & Extension (renames, undoably), Comments, Open with,
// Preview and Sharing & Permissions. The window is as tall as what's open.
// Placed on Finder's measurements, in points.
Window {
    id: win

    required property url startUrl
    readonly property url url: info.url
    readonly property bool looksActive: active
    readonly property Appearance appearance: Appearance {}
    readonly property int titleBar: 31

    width: Finder.infoWidth
    height: Math.min(titleBar + sections.height, Screen.desktopAvailableHeight - 40)
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: info.name + " Info"

    ItemInfo {
        id: info
        Component.onCompleted: url = win.startUrl
        // The fields show the item as it is now (another window renamed it,
        // an undo did), unless they're being edited.
        onChanged: {
            if (!nameInput.activeFocus)
                nameInput.text = name;
            if (!comments.activeFocus)
                comments.text = comment;
        }
    }

    // Name & Extension: a new name renames the item, as Finder's field does.
    property int renaming: -1
    function rename(name) {
        if (name === "" || name === info.name || renaming >= 0) {
            nameInput.text = info.name;
            return;
        }
        renaming = FileOps.rename(info.url, name);
    }
    Connections {
        target: FileOps
        function onFinished(id, urls, ok) {
            if (id !== win.renaming)
                return;
            win.renaming = -1;
            if (ok && urls.length > 0)
                info.url = urls[0];
            nameInput.text = info.name;
        }
    }
    // Closing the window keeps an edit in progress, as leaving its field does.
    onClosing: {
        if (comments.activeFocus && comments.text !== info.comment)
            info.comment = comments.text;
        if (nameInput.activeFocus && nameInput.text !== info.name)
            rename(nameInput.text);
    }

    Shortcut {
        sequences: ["Ctrl+W", "Meta+W"]
        onActivated: win.close()
    }

    onVisibleChanged: if (visible) App.decorate(win, Finder.infoRadius)
    Component.onCompleted: if (visible) App.decorate(win, Finder.infoRadius)

    // A row of General: its label right-aligned, its value after it.
    component Field: Item {
        id: field
        property string label
        property string value
        width: parent ? parent.width : 0
        height: 14
        Label {
            x: 68.5 - width
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 11
            text: field.label
        }
        Label {
            x: 71.5
            width: field.width - x - 10
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 11
            text: field.value
            elide: Text.ElideMiddle
        }
    }

    // A box a field is edited in.
    component Box: Rectangle {
        x: 12
        width: (parent ? parent.width : 0) - 24
        radius: 5
        color: Finder.infoPage
        border.width: 1
        border.color: Finder.infoRule
    }

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: Finder.infoRadius
        color: Finder.content
        border.width: 0.5
        border.color: Theme.dark ? "#33ffffff" : "#26000000"

        // The title bar: the lights, the item's icon and the window's name.
        Item {
            width: parent.width
            height: win.titleBar
            DragHandler {
                target: null
                onActiveChanged: if (active) win.startSystemMove()
            }
            TrafficLights {
                x: 8
                y: 8
                window: win
            }
            Row {
                x: 84
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                FileIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 16
                    kind: info.isDir ? "folder" : "document"
                    tint: info.tint
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    font.pixelSize: 13
                    font.weight: 700
                    text: win.title
                    color: win.active ? Theme.color.label.primary : Theme.color.label.secondary
                }
            }
            Rectangle {
                y: parent.height - 1
                width: parent.width
                height: 1
                color: Theme.dark ? "transparent" : Finder.infoRule
            }
        }

        Flickable {
            y: win.titleBar
            width: parent.width
            height: parent.height - y
            contentHeight: sections.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: sections
                width: parent.width

                // Its icon, name and size, when it last changed, and its tags.
                Item {
                    width: parent.width
                    height: 119 - win.titleBar
                    Thumbnail {
                        x: 10
                        y: 38 - win.titleBar
                        width: 32
                        height: 32
                        url: info.fileUrl
                        source: info.thumb
                        isDir: info.isDir
                        badge: info.badge
                        tint: info.tint
                    }
                    Label {
                        x: 48
                        y: 54 - win.titleBar - baselineOffset
                        width: sizeLabel.x - x - 8
                        font.pixelSize: 13
                        font.weight: 700
                        text: info.name
                        elide: Text.ElideMiddle
                    }
                    Label {
                        id: sizeLabel
                        x: parent.width - 9 - width
                        y: 54 - win.titleBar - baselineOffset
                        font.pixelSize: 13
                        text: info.size
                    }
                    Label {
                        x: 48
                        y: 70 - win.titleBar - baselineOffset
                        width: parent.width - x - 9
                        font.pixelSize: 11
                        text: "Modified: " + info.modified
                        color: Theme.color.label.secondary
                        elide: Text.ElideRight
                    }
                    // Its tags, a token each, then a field for another:
                    // Return adds it (a new tag joins the sidebar), ⌫ in the
                    // empty field takes the last away.
                    Rectangle {
                        x: 4
                        y: 83 - win.titleBar
                        width: parent.width - 8
                        height: 32
                        color: "transparent"
                        border.width: 1
                        border.color: info.tags.length === 0 || tagInput.activeFocus ? Finder.infoRule : "transparent"
                        TapHandler { onTapped: tagInput.forceActiveFocus() }
                        Flow {
                            x: 4
                            y: info.tags.length > 0 ? 2 : 9
                            width: parent.width - 8
                            spacing: 2
                            Repeater {
                                model: info.tags
                                Rectangle {
                                    id: token
                                    required property string modelData
                                    readonly property string color_: Tags.colorOf(modelData)
                                    width: tokenText.implicitWidth + 9
                                    height: 14
                                    radius: 2
                                    color: Finder.tagToken(color_)
                                    Label {
                                        id: tokenText
                                        anchors.centerIn: parent
                                        font.pixelSize: 11
                                        text: token.modelData
                                        color: Finder.tagTokenText(token.color_)
                                    }
                                }
                            }
                            TextInput {
                                id: tagInput
                                width: Math.max(80, contentWidth + 8)
                                height: 14
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                readOnly: !info.url.toString().startsWith("file:")
                                font.family: Theme.uiFont
                                font.pixelSize: 11
                                color: Theme.color.label.primary
                                selectionColor: Theme.accent.bg
                                selectedTextColor: Theme.accent.fg
                                renderType: Text.NativeRendering
                                Keys.onReturnPressed: {
                                    if (text.trim() !== "")
                                        Tags.add([info.url], text);
                                    text = "";
                                }
                                Keys.onEnterPressed: Keys.returnPressed(event)
                                Keys.onEscapePressed: {
                                    text = "";
                                    focus = false;
                                }
                                Keys.onPressed: (event) => {
                                    if (event.key === Qt.Key_Backspace && text === "" && info.tags.length > 0) {
                                        Tags.remove([info.url], info.tags[info.tags.length - 1]);
                                        event.accepted = true;
                                    }
                                }
                                Label {
                                    visible: info.tags.length === 0 && tagInput.text === ""
                                    x: -1
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: 13
                                    text: "Add Tags…"
                                    color: Theme.color.label.secondary
                                }
                            }
                        }
                    }
                }

                InfoSection {
                    title: "General:"
                    width: parent.width
                    Repeater {
                        model: [["Kind:", info.kind], ["Size:", info.sizeDetail], ["Where:", info.where],
                                ["Created:", info.created], ["Modified:", info.modified]].filter(row => row[1] !== "")
                        Field {
                            required property var modelData
                            label: modelData[0]
                            value: modelData[1]
                        }
                    }
                }

                InfoSection {
                    title: "More Info:"
                    width: parent.width
                    Label {
                        x: 12
                        height: 14
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 11
                        text: "Last opened: " + info.opened
                    }
                }

                InfoSection {
                    title: "Name & Extension:"
                    open: false
                    width: parent.width
                    Box {
                        height: 22
                        TextInput {
                            id: nameInput
                            anchors.fill: parent
                            anchors.leftMargin: 6
                            anchors.rightMargin: 6
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            readOnly: !info.url.toString().startsWith("file:")
                            text: info.name
                            font.family: Theme.uiFont
                            font.pixelSize: 13
                            color: Theme.color.label.primary
                            selectionColor: Theme.accent.bg
                            selectedTextColor: Theme.accent.fg
                            selectByMouse: true
                            renderType: Text.NativeRendering
                            onEditingFinished: win.rename(text)
                            Keys.onEscapePressed: {
                                text = info.name;
                                focus = false;
                            }
                        }
                    }
                }

                InfoSection {
                    title: "Comments:"
                    open: false
                    width: parent.width
                    Box {
                        height: 52
                        TextEdit {
                            id: comments
                            anchors.fill: parent
                            anchors.margins: 5
                            clip: true
                            text: info.comment
                            wrapMode: TextEdit.Wrap
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                            color: Theme.color.label.primary
                            selectionColor: Theme.accent.bg
                            selectedTextColor: Theme.accent.fg
                            selectByMouse: true
                            renderType: Text.NativeRendering
                            onActiveFocusChanged: if (!activeFocus && text !== info.comment) info.comment = text
                        }
                    }
                }

                InfoSection {
                    visible: !info.isDir && info.appName !== ""
                    title: "Open with:"
                    open: false
                    width: parent.width
                    Row {
                        x: 12
                        height: 18
                        spacing: 5
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            height: 16
                            source: info.appIcon !== "" ? "image://icon/" + info.appIcon : ""
                            sourceSize: Qt.size(32, 32)
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 11
                            text: info.appName + " (default)"
                        }
                    }
                }

                InfoSection {
                    title: "Preview:"
                    width: parent.width
                    Item {
                        width: parent.width
                        height: info.preview === "image" ? picture.height : info.preview === "text" ? 480 : 128
                        Image {
                            id: picture
                            visible: info.preview === "image"
                            x: 16.5
                            width: parent.width - 33
                            height: info.pictureSize.width > 0 ? Math.min(480, Math.round(width * info.pictureSize.height / info.pictureSize.width)) : 0
                            source: visible ? (info.thumb !== "" ? info.thumb : info.fileUrl) : ""
                            asynchronous: true
                            fillMode: Image.PreserveAspectFit
                            sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
                            smooth: true
                            mipmap: true
                        }
                        // Text, on a page of a letter's shape.
                        Rectangle {
                            visible: info.preview === "text"
                            x: 16.5
                            width: parent.width - 33
                            height: parent.height
                            radius: 6
                            color: Finder.infoPage
                            border.width: Theme.dark ? 0 : 1
                            border.color: Finder.infoRule
                            clip: true
                            Text {
                                x: 8
                                width: parent.width - 16
                                topPadding: 8
                                text: visible ? info.text.slice(0, 8000) : ""
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                                font.family: "monospace"
                                font.pixelSize: 11
                                lineHeightMode: Text.FixedHeight
                                lineHeight: 14
                                color: Theme.color.label.primary
                                renderType: Text.NativeRendering
                            }
                        }
                        FileIcon {
                            visible: info.preview === "generic"
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: 128
                            kind: info.isDir ? "folder" : "document"
                            badge: info.badge
                            tint: info.tint
                        }
                    }
                }

                InfoSection {
                    title: "Sharing & Permissions:"
                    open: false
                    width: parent.width
                    Label {
                        x: 12
                        height: 18
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 11
                        text: info.access + ":"
                    }
                    Box {
                        height: 18 * (1 + info.permissions.length) + 2
                        color: "transparent"
                        Column {
                            x: 1
                            y: 1
                            width: parent.width - 2
                            Repeater {
                                model: [{ name: "Name", privilege: "Privilege", head: true }].concat(info.permissions)
                                Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: parent.width
                                    height: 18
                                    color: index % 2 === 0 ? "transparent" : Finder.stripe
                                    Label {
                                        x: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.pixelSize: 11
                                        text: parent.modelData.name
                                        color: parent.modelData.head ? Theme.color.label.secondary : Theme.color.label.primary
                                    }
                                    Label {
                                        x: Math.round(parent.width * 0.58)
                                        anchors.verticalCenter: parent.verticalCenter
                                        font.pixelSize: 11
                                        text: parent.modelData.privilege
                                        color: parent.modelData.head ? Theme.color.label.secondary : Theme.color.label.primary
                                    }
                                }
                            }
                        }
                    }
                    Item { width: 1; height: 4 }
                }
            }
        }
    }
}
