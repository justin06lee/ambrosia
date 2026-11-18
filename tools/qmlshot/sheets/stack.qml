import QtQuick
import Ambrosia
import "../../../shell"

// A Dock stack opened: full, with a row to spare, and empty. The icons are
// the theme's app icons standing in for files' own.
Rectangle {
    id: sheet

    width: 1340
    height: 520
    gradient: Gradient {
        GradientStop { position: 0; color: shotDark ? "#1d2a44" : "#8fb4de" }
        GradientStop { position: 1; color: shotDark ? "#4a2f3a" : "#eebd97" }
    }

    Binding { target: Theme; property: "dark"; value: shotDark }

    readonly property string icons: Qt.resolvedUrl("../../../dist/icons/Ambrosia/apps/scalable/")
    readonly property var files: [
        ["ambrosia-2026.11.10-x86_64.iso", "ark"], ["Screenshot 2026-11-18 at 09.41.12.png", "gwenview"],
        ["notes.txt", "kate"], ["Invoice 2211.pdf", "okular"], ["wallpapers", "org.ambrosia.files"],
        ["budget.ods", "kcalc"], ["DESIGN.md", "kate"], ["a-very-long-file-name-that-will-not-fit-on-two-lines.tar.zst", "ark"],
        ["IMG_0042.jpeg", "gwenview"], ["keys.json", "kate"], ["Report.pdf", "okular"], ["build.log", "konsole"],
        ["one more.txt", "kate"], ["and another.png", "gwenview"],
    ]
    function things(count) {
        return files.slice(0, count).map(file => ({ name: file[0], icon: icons + file[1] + ".svg" }));
    }

    Row {
        anchors.centerIn: parent
        spacing: Theme.space.s8

        StackGrid { anchors.bottom: parent.bottom; items: sheet.things(14) }
        StackGrid { anchors.bottom: parent.bottom; items: sheet.things(6) }
        StackGrid { anchors.bottom: parent.bottom; items: [] }
    }
}
