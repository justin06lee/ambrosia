import QtQuick
import Ambrosia
import "../../../session/look-and-feel/org.ambrosia.desktop/contents/windowswitcher"

// ⌘Tab's strip with a few apps, and with more than fit at full size, over
// something like a wallpaper. The icons are the theme's own, as files; in
// KWin they come from each window.
Rectangle {
    id: sheet

    width: 1180
    height: 520
    gradient: Gradient {
        GradientStop { position: 0; color: shotDark ? "#1d2a44" : "#8fb4de" }
        GradientStop { position: 1; color: shotDark ? "#4a2f3a" : "#eebd97" }
    }

    Binding { target: Theme; property: "dark"; value: shotDark }

    readonly property string icons: "../../../dist/icons/Ambrosia/apps/scalable/"
    readonly property var names: ({
        "org.ambrosia.files": "Files", "konsole": "Terminal", "kate": "Text Editor", "gwenview": "Preview",
        "org.ambrosia.settings": "Settings", "kcalc": "Calculator", "okular": "Documents", "ark": "Archive Utility",
    })
    function apps(count) {
        const keys = Object.keys(names);
        const list = [];
        for (let i = 0; i < count; i++) list.push({ caption: names[keys[i % keys.length]], file: keys[i % keys.length] });
        return list;
    }

    component Strip: SwitcherStrip {
        id: strip
        property int apps
        model: ListModel {}
        Component.onCompleted: sheet.apps(apps).forEach(app => model.append(app))
        icon: Image {
            anchors.fill: parent
            source: parent ? sheet.icons + parent.entry.file + ".svg" : ""
            sourceSize: Qt.size(2 * width, 2 * height)
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.space.s12

        Strip { anchors.horizontalCenter: parent.horizontalCenter; apps: 6; currentIndex: 2 }
        Strip { anchors.horizontalCenter: parent.horizontalCenter; apps: 15; currentIndex: 11; maxWidth: sheet.width * 0.9 }
    }
}
