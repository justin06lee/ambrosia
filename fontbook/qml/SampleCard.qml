import QtQuick
import Ambrosia
import FontBook

// A sample on its card: a name in bold with a line under it, a line of
// text in the font at the size asked, and the style's name at the foot.
// 196 tall with text of 34; taller or shorter with the text.
Rectangle {
    id: card

    required property var window
    property string title
    property string subtitle
    property string footer
    property string sample
    property string family
    property string styleName
    property int size: 34
    property bool locked: false
    property bool chosen: false

    height: Math.round(196 + 1.3 * (size - 34))
    radius: 14
    color: Look.sampleFill
    border.width: chosen ? 2.5 : 1
    border.color: chosen ? Look.chosen(window.looksActive) : Look.sampleRim

    Label {
        x: 25
        y: 13
        width: parent.width - 70
        elide: Text.ElideRight
        text: card.title
        font.weight: 700
        color: card.window.looksActive ? Look.text : Look.textInactive
    }
    Label {
        x: 25
        y: 31
        visible: card.subtitle !== ""
        text: card.subtitle
        style: Theme.text.footnote
        font.pixelSize: 12
        color: card.window.looksActive ? Look.text : Look.textInactive
    }
    Glyph {
        visible: card.locked
        x: parent.width - 18 - width
        y: 15
        name: "lock"
        size: 12
        color: Look.heading
    }
    Item {
        x: 25
        y: 50
        width: parent.width - 50
        height: parent.height - 50 - 40
        clip: true
        Text {
            width: parent.width
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 4
            text: card.sample
            font.family: card.family
            font.styleName: card.styleName
            font.pixelSize: card.size
            color: card.window.looksActive ? Look.text : Look.textInactive
        }
    }
    Label {
        x: 25
        y: parent.height - 28 - height / 2
        text: card.footer
        style: Theme.text.caption
        color: card.window.looksActive ? Look.text : Look.textInactive
    }
}
