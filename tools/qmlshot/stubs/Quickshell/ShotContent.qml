import QtQuick
import QtQuick.Effects
import Quickshell

// What a stand-in window draws in: an item on the sheet's screen. Under its
// children it draws what the window asked the compositor to blur, as a blur
// of the screen's backdrop (KWin's own blur is a different one; this stands
// for it).
Item {
    id: content

    // The window this is the content of (QsWindow.window finds it by this).
    property QtObject shotWindow: null
    property QtObject blurRegion: null
    readonly property Item backdrop: shotWindow?.screen?.shotBackdrop ?? null

    // The regions asked for, each as { x, y, width, height, radius } here.
    property var blurs: []
    function flatten(region, into) {
        if (!region) return;
        const item = region.item;
        if (item && item.visible && item.width > 0 && item.height > 0) {
            const at = item.mapToItem(content, 0, 0);
            into.push({ x: at.x, y: at.y, width: item.width, height: item.height, radius: region.radius ?? 0 });
        }
        for (const inner of region.regions ?? []) flatten(inner, into);
    }
    function settle() {
        const found = [];
        if (backdrop && visible) flatten(blurRegion, found);
        if (JSON.stringify(found) !== JSON.stringify(blurs)) blurs = found;
    }
    // Regions follow items that move and fade; looked at again as they go.
    Timer {
        interval: 50
        running: content.backdrop !== null
        repeat: true
        triggeredOnStart: true
        onTriggered: content.settle()
    }

    Repeater {
        model: content.blurs

        Item {
            id: blur
            required property var modelData
            readonly property point origin: (content.blurs, content.mapToItem(content.backdrop, modelData.x, modelData.y))
            x: modelData.x
            y: modelData.y
            z: -1
            width: modelData.width
            height: modelData.height

            ShaderEffectSource {
                id: behind
                anchors.fill: parent
                sourceItem: content.backdrop
                sourceRect: Qt.rect(blur.origin.x, blur.origin.y, blur.width, blur.height)
                visible: false
            }
            Rectangle {
                id: shape
                anchors.fill: parent
                radius: Math.min(blur.modelData.radius, width / 2, height / 2)
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: parent
                source: behind
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1
                blurMax: 64
                saturation: 0.4
                maskEnabled: true
                maskSource: shape
            }
        }
    }
}
