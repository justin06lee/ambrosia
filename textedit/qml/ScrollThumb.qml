import QtQuick
import QtQuick.Controls.Basic as Controls
import Ambrosia

// A scroll bar as our lists draw it (Files' ListPane): a thin rounded thumb
// that shows while the view moves or the pointer is on it, on no track.
Controls.ScrollBar {
    id: bar

    policy: Controls.ScrollBar.AsNeeded
    padding: 3
    contentItem: Rectangle {
        implicitWidth: Theme.size.scrollbar.thin
        implicitHeight: Theme.size.scrollbar.thin
        radius: Math.min(width, height) / 2
        color: Theme.color.label.tertiary
        // Nothing to scroll, no thumb (the pointer over it would show one).
        opacity: bar.active && bar.size < 1 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fade.base } }
    }
    background: null
}
