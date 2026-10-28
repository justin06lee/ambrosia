import QtQuick
import Ambrosia
import Settings

// The toolbar over the content: back and forward in a glass capsule, then
// the pane's name. Positions are the window's.
Item {
    id: toolbar

    required property var settings

    height: Look.toolbar

    Capsule {
        id: nav
        x: Look.navX
        y: Look.navY
        width: Look.navWidth

        Repeater {
            model: [
                { glyph: "back", enabled: toolbar.settings.canGoBack, act: () => toolbar.settings.back() },
                { glyph: "forward", enabled: toolbar.settings.canGoForward, act: () => toolbar.settings.forward() },
            ]
            Item {
                id: button
                required property var modelData
                required property int index
                width: Look.control
                height: Look.control

                Rectangle {
                    anchors.centerIn: parent
                    width: 30
                    height: 28
                    radius: height / 2
                    color: Theme.color.fill.tertiary
                    visible: tap.pressed && button.modelData.enabled
                }
                Glyph {
                    anchors.centerIn: parent
                    name: button.modelData.glyph
                    size: 22
                    color: button.modelData.enabled ? Theme.color.label.primary : Theme.color.label.tertiary
                }
                TapHandler {
                    id: tap
                    enabled: button.modelData.enabled
                    onTapped: button.modelData.act()
                }
            }
        }
    }
    // Between the two halves.
    Rectangle {
        x: nav.x + Look.control
        y: nav.y + (Look.control - height) / 2
        width: 1
        height: 18
        color: Look.capsuleDivider
    }

    Label {
        x: Look.titleX
        width: parent.width - x - 12
        height: Look.toolbar
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: toolbar.settings.title
        style: Theme.text.title3
        color: toolbar.settings.looksActive ? Theme.color.label.primary : Theme.color.label.tertiary
    }
}
