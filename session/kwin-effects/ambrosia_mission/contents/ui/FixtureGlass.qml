import QtQuick
import QtQuick.Effects
import org.kde.kwin as KWin
import org.ambrosia.glass.kwin as Glass
import Ambrosia

// Glass behind a window Mission Control draws as a picture (the menu bar,
// the Dock, a banner). The compositor's glass is drawn behind windows, not
// behind pictures of them, so here each of the window's panes shows the
// wallpaper once more, blurred and saturated as the pane's material asks,
// inside the pane's own corner. The panes are the ones the window named to
// Ambrosia's glass effect, which is asked for them: where that effect has
// never been loaded this file doesn't load either, and the pictures stay
// as they were, on the bare wallpaper.
Item {
    id: glass

    // The window whose picture lies over this, the screen's windows (the
    // wallpaper is found among them) and the screen's view.
    required property QtObject window
    required property var windows
    required property Item view

    // A material's blur in MultiEffect's terms. Its blurMax is no plain
    // multiple of the Gaussian it gives, so this is a table, measured in the
    // test VM against one hard edge (tools/blur.py), a strip a setting: the
    // Gaussian, then the blurMax that gave it. Past 128 it gives no more.
    readonly property var measured: [[0, 0], [11.6, 40], [15.0, 48], [17.9, 56], [20.7, 64], [24.5, 72], [26.2, 80], [27.4, 96], [31.7, 112], [32.5, 128]]
    function reach(gaussian) {
        for (let i = 1; i < measured.length; i++) {
            const [low, from] = measured[i - 1];
            const [high, to] = measured[i];
            if (gaussian <= high)
                return Math.round(from + (to - from) * (gaussian - low) / (high - low));
        }
        return measured[measured.length - 1][1];
    }

    property int revision: 0
    readonly property var panes: {
        revision;
        return Glass.Panes.panesOf(window);
    }

    Connections {
        target: Glass.Panes
        function onPanesChanged() {
            glass.revision++;
        }
    }

    Repeater {
        model: glass.panes

        delegate: Item {
            id: pane

            required property var modelData
            readonly property QtObject material: Theme.material[modelData.material] ?? Theme.material.regular

            x: modelData.x
            y: modelData.y
            width: modelData.width
            height: modelData.height
            opacity: modelData.opacity

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: outline
            }

            Item {
                anchors.fill: parent
                clip: true

                Repeater {
                    model: glass.windows

                    delegate: Loader {
                        required property QtObject window

                        // From the pane's corner to the wallpaper's.
                        x: window.x - glass.window.x - pane.x
                        y: window.y - glass.window.y - pane.y
                        active: false
                        Component.onCompleted: active = glass.view.isBackdrop(window)
                        sourceComponent: KWin.WindowThumbnail {
                            wId: window.internalId
                            width: window.width
                            height: window.height
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                blurEnabled: true
                                blur: 1
                                blurMax: glass.reach(pane.material.blur)
                                // No room round the picture for the blur
                                // to fade into: at the screen's edge it
                                // would let the bare wallpaper through.
                                autoPaddingEnabled: false
                                saturation: pane.material.saturate - 1
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: outline
                anchors.fill: parent
                radius: Math.min(pane.modelData.radius, width / 2, height / 2)
                visible: false
                layer.enabled: true
            }
        }
    }
}
