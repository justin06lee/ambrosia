import QtQuick
import QtQuick.Window
import org.kde.kwin as KWin
import org.kde.kirigami as Kirigami
import org.ambrosia.kwin as AmbrosiaKWin
import Ambrosia

// ⌘Tab: the running apps as a row of icons in the middle of the screen, as
// on a Mac. KWin's own switcher does the keys (hold, Tab on, let go to
// switch) and gives the list; the session's kwinrc has it show one window an
// app and names this layout (KWin looks for it in the look-and-feel package
// first). While it is up: ← and → move, Q closes the chosen app's window,
// the pointer chooses what it moves over, a click switches.
KWin.TabBoxSwitcher {
    id: tabBox

    // An app's name, from its window. KWin's list has the window's title,
    // which is the document's; the window knows its desktop file's name
    // (org.kde.konsole), and that file has the app's.
    function appName(windows, windowId, caption) {
        const id = String(windowId);
        const window = windows.find(w => String(w.internalId) === id);
        const file = window?.desktopFileName ?? "";
        // (A KWin still running from before an upgrade may hold a module
        // without Apps.)
        const name = AmbrosiaKWin.Apps?.name(file) ?? "";
        if (name) return name;
        // No desktop file: the last word of what the window calls itself.
        const word = (file || window?.resourceClass || "").split(".").pop();
        return word ? word.charAt(0).toUpperCase() + word.slice(1) : caption;
    }

    Instantiator {
        active: tabBox.visible

        delegate: Window {
            // Room round the strip for its shadow.
            readonly property int room: 64
            // KWin's windows as they are when this opens. (Read once it is
            // made: the list says nothing when it changes, and a binding
            // that read it would be warned about each time.)
            property var windows: []
            Component.onCompleted: windows = KWin.Workspace.windows

            visible: true
            flags: Qt.ToolTip | Qt.FramelessWindowHint
            color: "transparent"
            width: strip.width + 2 * room
            height: strip.height + 2 * room
            x: tabBox.screenGeometry.x + Math.round((tabBox.screenGeometry.width - width) / 2)
            y: tabBox.screenGeometry.y + Math.round((tabBox.screenGeometry.height - height) / 2)

            // KWin's colors are the color scheme's: dark when its window
            // color is. (Here, not above: the switcher takes one child.)
            SystemPalette { id: system }
            Binding { target: Theme; property: "dark"; value: system.window.hslLightness < 0.5 }

            // KWin blurs behind its own windows only where it is told to
            // (the shell's glass asks as a Wayland client; this can't).
            AmbrosiaKWin.BlurBehind { item: strip; radius: strip.radius }

            SwitcherStrip {
                id: strip

                function step(by) {
                    if (count > 0) tabBox.currentIndex = (tabBox.currentIndex + by + count) % count;
                }

                anchors.centerIn: parent
                focus: true
                model: tabBox.model
                currentIndex: tabBox.currentIndex
                maxWidth: tabBox.screenGeometry.width * 0.9
                nameOf: entry => tabBox.appName(windows, entry.windowId, entry.caption)
                icon: Kirigami.Icon {
                    anchors.fill: parent
                    source: parent ? parent.entry.icon : ""
                }
                onPointed: index => tabBox.currentIndex = index
                onChosen: index => tabBox.model.activate(index)

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Left) step(-1);
                    else if (event.key === Qt.Key_Right) step(1);
                    else if (event.key === Qt.Key_Q) tabBox.model.close(tabBox.currentIndex);
                }
            }

            onSceneGraphError: () => {
                // As KWin's own layout does: left empty, or Qt Quick may end
                // KWin over a graphics reset.
            }
        }
    }
}
