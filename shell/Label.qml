import QtQuick
import Ambrosia

// Text in the Ambrosia type scale; `style` is one of Theme.text's styles.
Text {
    property QtObject style: Theme.text.body

    font.family: Theme.uiFont
    font.pixelSize: style.size
    font.weight: style.weight
    font.letterSpacing: style.tracking
    color: Theme.color.label.primary
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
