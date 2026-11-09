import QtQuick
import Ambrosia
import Settings

// A network's lock (if it takes a password) and its signal in three bars,
// side by side as System Settings sets them: the lock 9 wide, then the
// signal's 14.5, `pitch` from the lock's left (25 by the network in use).
Item {
    id: signal

    property bool secure
    property int bars: 3
    property real pitch: 20

    implicitWidth: pitch + 17
    implicitHeight: 13

    Glyph {
        visible: signal.secure
        x: 0
        y: 0.83
        name: "lock"
        size: 13
    }
    Glyph {
        x: signal.pitch + 1.8
        y: -0.72
        name: "signal" + Math.max(1, Math.min(3, signal.bars))
        size: 15
    }
}
