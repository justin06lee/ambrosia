pragma Singleton
import QtQuick

// Shows the Colors panel (ColorPanel.qml): one for the app, brought forward
// if it is already up. Whoever asks says the color to start from and what
// to do with each color chosen: Colors.show(color, (chosen) => …, window).
// The panel stays up and goes on telling until it is asked for something
// else or closed, as a Mac's does. The eyedropper is KWin's own picker
// (screencolor.h).
QtObject {
    id: colors

    property var panel: null
    property var apply: null
    property Component window: Component { ColorPanel {} }

    property Connections heard: Connections {
        target: colors.panel
        function onPicked(color) {
            if (colors.apply)
                colors.apply(color);
        }
        function onDropper() {
            ScreenColor.pick();
        }
        function onVisibleChanged() {
            if (colors.panel && !colors.panel.visible)
                colors.apply = null;
        }
    }
    property Connections dropped: Connections {
        target: ScreenColor
        function onPicked(color) {
            if (colors.panel && colors.panel.visible)
                colors.panel.take(color, true);
        }
    }

    // `over`: the window it belongs to (it stays above that one).
    function show(color, apply, over) {
        if (!panel)
            panel = window.createObject(null, { canDrop: true });
        colors.apply = null;
        panel.present(color);
        colors.apply = apply ?? null;
        if (over)
            panel.transientParent = over;
        panel.show();
        panel.raise();
        panel.requestActivate();
    }
    // The color shown, when what it is the color of changed elsewhere (the
    // selection moved, another window came forward): nobody is told, and
    // `apply`, if given, hears from now on.
    function follow(color, apply) {
        if (!panel || !panel.visible)
            return;
        const was = colors.apply;
        colors.apply = null;
        panel.present(color);
        colors.apply = apply ?? was;
    }
    readonly property bool shown: panel !== null && panel.visible
}
