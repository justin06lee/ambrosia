import QtQuick
import Ambrosia

// Text in the Ambrosia type scale, as the shell's Label.qml: `style` is one
// of Theme.text's styles (null for a moment while a label is built).
Text {
    property QtObject style: Theme.text.body

    font.family: Theme.uiFont
    font.pixelSize: style?.size ?? 13
    font.weight: style?.weight ?? 400
    font.letterSpacing: style?.tracking ?? 0
    color: Theme.color.label.primary
    renderType: Text.NativeRendering
}
