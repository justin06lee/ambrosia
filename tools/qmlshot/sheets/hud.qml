import QtQuick
import Ambrosia
import "../../../shell"

// The volume and brightness keys' display in its states, over something
// like a wallpaper (the compositor's blur isn't here to soften it).
Rectangle {
    id: sheet

    width: 2 * column + 3 * Theme.space.s8
    height: 3 * (Theme.size.hud.height + Theme.space.s8) + Theme.space.s8
    readonly property int column: Theme.size.hud.width
    gradient: Gradient {
        GradientStop { position: 0; color: shotDark ? "#1d2a44" : "#8fb4de" }
        GradientStop { position: 1; color: shotDark ? "#4a2f3a" : "#eebd97" }
    }

    Binding { target: Theme; property: "dark"; value: shotDark }

    Grid {
        anchors.centerIn: parent
        columns: 2
        spacing: Theme.space.s8

        HudPanel { glyph: "speaker"; level: 0.62 }
        HudPanel { glyph: "sun"; level: 0.85 }
        HudPanel { glyph: "speakerOff"; level: 0 }
        HudPanel { glyph: "speaker"; level: 1 }
        HudPanel { text: "Justin's AirPods Pro" }
        HudPanel { glyph: "sun"; level: 0.06 }
    }
}
