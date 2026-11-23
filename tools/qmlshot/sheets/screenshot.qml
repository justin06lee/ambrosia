import QtQuick
import Ambrosia
import "../../../shell"

// A screenshot's thumbnail as it floats in the screen's corner: a wide
// picture, a tall one (a part of the screen) and one not read yet, over
// something like a wallpaper.
Rectangle {
    id: sheet

    width: 3 * Theme.size.screenshot.width + 4 * Theme.space.s8
    height: Theme.size.screenshot.height + 2 * Theme.space.s8
    gradient: Gradient {
        GradientStop { position: 0; color: shotDark ? "#1d2a44" : "#8fb4de" }
        GradientStop { position: 1; color: shotDark ? "#4a2f3a" : "#eebd97" }
    }

    Binding { target: Theme; property: "dark"; value: shotDark }

    Row {
        anchors.centerIn: parent
        spacing: Theme.space.s8

        ScreenshotThumb { anchors.bottom: parent.bottom; source: Qt.resolvedUrl("art/shot-wide.svg") }
        ScreenshotThumb { anchors.bottom: parent.bottom; source: Qt.resolvedUrl("art/shot-tall.svg") }
        ScreenshotThumb { anchors.bottom: parent.bottom }
    }
}
