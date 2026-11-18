import QtQuick

// A part of a window, named by an item or made of other regions. The
// stand-in windows ignore masks and draw blur regions (ShotContent).
QtObject {
    property Item item: null
    property real radius: 0
    property var regions: []
    property int x: 0
    property int y: 0
    property int width: 0
    property int height: 0
    property int intersection: 0
    property int shape: 0
}
