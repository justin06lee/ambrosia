import QtQuick
import QtQuick.Shapes
import Ambrosia
import TextEditor

// The ruler over rich text, as macOS 27's TextEdit draws it (Look.qml): a
// line with a mark every centimetre (every half inch where inches are
// used), numbered at the longer ones, and over it the markers of the
// paragraph the cursor is in: the first line's indent (a bar), the left
// and right indents (the points under it and at the far end), and each tab
// stop (an arrowhead). Dragging one moves it for the paragraphs selected;
// a tab stop dragged off the ruler is gone, and a click on the ruler
// where there is none makes one.
Item {
    id: ruler

    required property var window
    readonly property Editor editor: window.editor
    // How wide the text is, between its margins.
    property real textWidth: 0
    readonly property bool metric: Qt.locale().measurementSystem === Locale.MetricSystem
    readonly property real unit: metric ? Look.centimetre : Look.inch
    // Marks: one a centimetre, numbered every second; or one a half
    // inch, numbered at the inch.
    readonly property real mark: metric ? unit : unit / 2
    readonly property real step: metric ? unit / 4 : unit / 8
    readonly property real line: Look.rulerLine - Look.formatBar
    readonly property real leftIndent: editor.leftIndent
    readonly property real firstIndent: editor.firstIndent
    readonly property real rightIndent: editor.rightIndent
    readonly property var tabs: editor.tabs
    readonly property bool list: editor.listMarker !== ""

    function snapped(position) {
        return Math.round(position / step) * step;
    }
    function place(x) {
        return snapped(Math.max(0, Math.min(textWidth, x - Look.rulerOrigin)));
    }

    clip: true

    Rectangle { anchors.fill: parent; color: Look.rulerFill }
    Rectangle { width: parent.width; height: 0.5; color: Look.barLine }
    Rectangle { y: ruler.line; width: parent.width; height: 1; color: Look.rulerMark }
    Rectangle { y: parent.height - 1.5; width: parent.width; height: 1; color: Look.rulerEdge }

    Repeater {
        model: Math.ceil(ruler.width / ruler.mark) + 1
        Item {
            id: tick
            required property int index
            readonly property bool numbered: index % 2 === 0
            x: Look.rulerOrigin - 0.5 + index * ruler.mark
            Rectangle {
                y: ruler.line
                width: 1
                height: tick.numbered ? 11 : 5.5
                color: Look.rulerMark
            }
            Text {
                visible: tick.numbered
                x: 4
                y: ruler.line + 3.5
                text: ruler.metric ? tick.index : tick.index / 2
                font.family: Theme.uiFont
                font.pixelSize: 10
                color: Look.rulerNumber
                renderType: Text.NativeRendering
            }
        }
    }

    // A click where no marker is: a tab stop there.
    MouseArea {
        anchors.fill: parent
        enabled: !ruler.list
        onClicked: (mouse) => {
            const at = ruler.place(mouse.x);
            if (at > 0 && !ruler.tabs.some(tab => Math.abs(tab - at) < 1))
                ruler.editor.setTabs(ruler.tabs.concat([at]));
        }
    }

    // What a marker is drawn with, and how one is dragged: `position` is
    // where it stands, `moved(to)` what a drag ends in; a tab stop let go
    // off the ruler is `dropped`.
    component Marker: Item {
        id: marker
        property real position: 0
        property string path
        property real shapeWidth: 9
        property bool removable: false
        // Where it takes the pointer, from its own top: the first line's
        // bar and the left indent's point stand one over the other.
        property real hitY: -2
        property real hitHeight: 13
        property real dragged: -1
        readonly property real shown: dragged >= 0 ? dragged : position
        property bool away: false
        signal moved(real to)
        signal dropped()

        x: Look.rulerOrigin + shown - shapeWidth / 2
        width: shapeWidth
        opacity: away ? 0.3 : 1
        visible: !ruler.list

        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillColor: Look.marker
                PathSvg { path: marker.path }
            }
        }
        MouseArea {
            x: -3
            y: marker.hitY
            width: parent.shapeWidth + 6
            height: marker.hitHeight
            preventStealing: true
            onPositionChanged: (mouse) => {
                const inRuler = mapToItem(ruler, mouse.x, mouse.y);
                marker.dragged = ruler.place(inRuler.x);
                marker.away = marker.removable && (inRuler.y < -14 || inRuler.y > ruler.height + 14);
            }
            onReleased: {
                const to = marker.dragged, away = marker.away;
                marker.dragged = -1;
                marker.away = false;
                if (away)
                    marker.dropped();
                else if (to >= 0 && Math.abs(to - marker.position) > 0.01)
                    marker.moved(to);
            }
            onCanceled: {
                marker.dragged = -1;
                marker.away = false;
            }
        }
    }

    Repeater {
        model: ruler.tabs
        Marker {
            required property real modelData
            required property int index
            y: 5
            shapeWidth: 6
            // The stop is at the arrowhead's flat side.
            x: Look.rulerOrigin + shown
            position: modelData
            path: "M0 0L6 4.6L0 9.2z"
            removable: true
            onMoved: (to) => ruler.editor.setTabs(ruler.tabs.map((tab, i) => i === index ? to : tab))
            onDropped: ruler.editor.setTabs(ruler.tabs.filter((tab, i) => i !== index))
        }
    }
    // The right indent, from the text's right edge.
    Marker {
        y: 8.5
        position: ruler.textWidth - ruler.rightIndent
        path: "M0 0h9v2L4.5 6L0 2z"
        hitY: 0.5
        hitHeight: 10
        onMoved: (to) => ruler.editor.setIndents(ruler.leftIndent, ruler.firstIndent, Math.max(0, ruler.textWidth - Math.max(to, ruler.leftIndent + 2 * ruler.step)))
    }
    // The left indent: the first line stays where it is.
    Marker {
        y: 8.5
        position: ruler.leftIndent
        path: "M0 0h9v2L4.5 6L0 2z"
        hitY: 0.5
        hitHeight: 10
        onMoved: (to) => {
            const left = Math.min(to, ruler.textWidth - ruler.rightIndent - 2 * ruler.step);
            ruler.editor.setIndents(left, ruler.leftIndent + ruler.firstIndent - left, ruler.rightIndent);
        }
    }
    // The first line's indent.
    Marker {
        y: 4.5
        position: ruler.leftIndent + ruler.firstIndent
        path: "M0 0h9v2h-4v2h-1v-2h-4z"
        hitY: -3
        hitHeight: 7.5
        onMoved: (to) => ruler.editor.setIndents(ruler.leftIndent, Math.min(to, ruler.textWidth - ruler.rightIndent - 2 * ruler.step) - ruler.leftIndent, ruler.rightIndent)
    }
}
