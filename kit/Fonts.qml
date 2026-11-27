pragma Singleton
import QtQuick

// Shows the Fonts panel (FontPanel.qml): one for the app, brought forward
// if it is already up. Whoever asks says who knows the fonts (`source`:
// families, styles(family), style(family, name)), the font to start from
// ({ family, weight, italic, size }) and what to do with each one chosen:
// Fonts.show(App, font, (family, weight, italic, size, what) => …, window);
// `what` is which of them was chosen: "family", "face" or "size". The
// panel stays up and goes on telling until it is asked for something else
// or closed, as a Mac's does.
QtObject {
    id: fonts

    property var panel: null
    property var apply: null
    property Component window: Component { FontPanel {} }

    property Connections heard: Connections {
        target: fonts.panel
        function onPicked(family, weight, italic, size, what) {
            if (fonts.apply)
                fonts.apply(family, weight, italic, size, what);
        }
        function onVisibleChanged() {
            if (fonts.panel && !fonts.panel.visible)
                fonts.apply = null;
        }
    }

    // `over`: the window it belongs to (it stays above that one).
    function show(source, font, apply, over) {
        if (!panel)
            panel = window.createObject(null);
        fonts.apply = null;
        panel.source = source;
        panel.present(font.family, font.weight, font.italic, font.size);
        fonts.apply = apply ?? null;
        if (over)
            panel.transientParent = over;
        panel.show();
        panel.raise();
        panel.requestActivate();
    }
    // The font shown, when what it is the font of changed elsewhere (the
    // selection moved, another window came forward): nobody is told, and
    // `apply`, if given, hears from now on.
    function follow(font, apply) {
        if (!panel || !panel.visible)
            return;
        const was = fonts.apply;
        fonts.apply = null;
        panel.present(font.family, font.weight, font.italic, font.size);
        fonts.apply = apply ?? was;
    }
    readonly property bool shown: panel !== null && panel.visible
}
