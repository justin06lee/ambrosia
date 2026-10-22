import QtQuick
import QtQuick.Shapes
import QtQuick.Window
import Ambrosia
import Files

// Quick Look (Space, ⌘Y): the item selected, in a dark panel over its
// window. A picture shows as itself at one point a pixel (smaller if the
// screen is), text as text, anything else as its icon beside its name, size
// and date. It follows the window's selection: the arrows move it, Space,
// Esc or ⌘Y close it. Placed on Finder's measurements, in points.
Window {
    id: look

    required property var finder
    readonly property var shown: finder.shownInfo

    readonly property int bar: 38 // the title bar
    readonly property bool picture: info.preview === "image"
    readonly property bool text: info.preview === "text"
    readonly property bool full: visibility === Window.FullScreen
    // The panel's size for what it shows: a picture with a 5-point frame
    // beside and below it, fitted to the screen; text in Finder's page;
    // anything else in the small panel.
    readonly property size natural: {
        if (picture) {
            const p = info.pictureSize;
            const k = Math.min(1, (Screen.desktopAvailableWidth * 0.85 - 10) / p.width,
                               (Screen.desktopAvailableHeight * 0.85 - bar - 5) / p.height);
            return Qt.size(Math.round(p.width * k) + 10, Math.round(p.height * k) + bar + 5);
        }
        if (text)
            return Qt.size(816, Math.min(849, Math.round(Screen.desktopAvailableHeight * 0.9)));
        return Qt.size(576, 328);
    }

    width: natural.width
    height: natural.height
    visible: true
    color: "transparent"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: info.name

    ItemInfo {
        id: info
        url: look.shown.url ?? ""
    }

    // Space, Esc and ⌘Y close it; every other key is the window's, as if
    // it had the keyboard (the arrows move the selection, and this with it).
    function keyPressed(event) {
        const ctrl = event.modifiers & (Qt.ControlModifier | Qt.MetaModifier);
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Escape || (ctrl && event.key === Qt.Key_Y)) {
            event.accepted = true;
            if (full)
                showNormal();
            else
                finder.closeLook();
            return;
        }
        finder.keyPressed(event);
    }

    onVisibleChanged: if (visible) App.decorate(look, Finder.lookRadius)
    Component.onCompleted: if (visible) App.decorate(look, Finder.lookRadius)

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: look.full ? 0 : Finder.lookRadius
        color: Finder.lookFill
        border.width: 1
        border.color: Finder.lookRim
        focus: true
        Keys.onPressed: (event) => look.keyPressed(event)

        DragHandler {
            target: null
            onActiveChanged: if (active) look.startSystemMove()
        }

        // Close and full screen: filled circles, their glyphs cut out.
        Repeater {
            model: [
                { x: 18, stroke: "M3.9 3.9l4.2 4.2M8.1 3.9l-4.2 4.2", fill: "", act: () => look.finder.closeLook() },
                { x: 38, stroke: "", fill: "M3.3 3.3h4L3.3 7.3zM8.7 8.7h-4l4-4z",
                  act: () => look.full ? look.showNormal() : look.showFullScreen() },
            ]
            Rectangle {
                id: circle
                required property var modelData
                x: modelData.x - 6
                y: look.bar / 2 - 6
                width: 12
                height: 12
                radius: 6
                color: Finder.lookControl
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: circle.modelData.stroke ? Finder.lookFill : "transparent"
                        strokeWidth: 1.5
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathSvg { path: circle.modelData.stroke }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: circle.modelData.fill ? Finder.lookFill : "transparent"
                        PathSvg { path: circle.modelData.fill }
                    }
                }
                TapHandler { onTapped: circle.modelData.act() }
            }
        }

        // The name, beside the circles, over a picture or text.
        Label {
            visible: look.picture || look.text
            x: 53
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: look.bar / 2
            width: openButton.x - x - 12
            font.pixelSize: 13
            font.weight: 700
            text: info.name
            elide: Text.ElideMiddle
        }

        // "Open with Preview": the app that opens it, as Finder names it.
        Rectangle {
            id: openButton
            visible: !info.isDir && info.appName !== ""
            x: visible ? panel.width - 8 - width : panel.width
            anchors.verticalCenter: parent.top
            anchors.verticalCenterOffset: look.bar / 2
            width: openText.implicitWidth + 22
            height: 23.5
            radius: height / 2
            color: Finder.lookButton
            Label {
                id: openText
                anchors.centerIn: parent
                font.pixelSize: 13
                font.weight: 500
                text: "Open with " + info.appName
                color: Finder.lookButtonText
            }
            TapHandler {
                onTapped: {
                    App.openFile(info.url);
                    look.finder.closeLook();
                }
            }
        }

        // A picture, as itself.
        Image {
            visible: look.picture
            x: 5
            y: look.bar
            width: parent.width - 10
            height: parent.height - look.bar - 5
            source: look.picture ? info.fileUrl : ""
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
            smooth: true
            mipmap: true
        }

        // Text, in its page.
        Rectangle {
            visible: look.text
            x: 5
            y: look.bar
            width: parent.width - 10
            height: parent.height - look.bar - 5
            radius: 8
            color: Finder.lookPage
            Flickable {
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                contentHeight: page.height
                boundsBehavior: Flickable.StopAtBounds
                Text {
                    id: page
                    x: 7
                    width: parent.width - 14
                    // The first baseline 13 below the page's top, lines 13 apart.
                    topPadding: 12 - mono.ascent
                    bottomPadding: 12
                    text: look.text ? info.text : ""
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    font: mono.font
                    lineHeightMode: Text.FixedHeight
                    lineHeight: 13
                    color: Theme.color.label.primary
                    renderType: Text.NativeRendering
                }
            }
            FontMetrics {
                id: mono
                font.family: "monospace"
                font.pixelSize: 11
            }
        }

        // Anything else: its icon, and beside it its name, size and date.
        Item {
            visible: !look.picture && !look.text
            anchors.fill: parent
            FileIcon {
                x: 20
                y: 48
                size: 256
                kind: info.isDir ? "folder" : "document"
                badge: info.badge
            }
            Label {
                id: bigName
                x: 298.5
                y: 150 - baselineOffset
                width: parent.width - x - 20
                font.pixelSize: 23
                font.weight: 700
                text: info.name
                elide: Text.ElideMiddle
            }
            Label {
                x: bigName.x
                y: 175.5 - baselineOffset
                font.pixelSize: 13
                text: info.sizeSummary
                color: Theme.color.label.secondary
            }
            Label {
                x: bigName.x
                y: 199.5 - baselineOffset
                font.pixelSize: 13
                text: "Last modified " + info.modifiedSeconds
                color: Theme.color.label.secondary
            }
        }
    }
}
