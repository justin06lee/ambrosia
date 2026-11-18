import QtQuick
import Ambrosia
import "../../../shell"

// A Dock stack opened: full, with a row to spare, and empty. The icons are
// the theme's own for each kind of file (dist/icons/Ambrosia); one picture
// can't be read and wears its kind's instead.
Rectangle {
    id: sheet

    width: 1340
    height: 520
    gradient: Gradient {
        GradientStop { position: 0; color: shotDark ? "#1d2a44" : "#8fb4de" }
        GradientStop { position: 1; color: shotDark ? "#4a2f3a" : "#eebd97" }
    }

    Binding { target: Theme; property: "dark"; value: shotDark }

    readonly property string icons: Qt.resolvedUrl("../../../dist/icons/Ambrosia/")
    readonly property var files: [
        ["ambrosia-2026.11.10-x86_64.iso", "mimetypes/scalable/unknown"], ["Screenshot 2026-11-18 at 09.41.12.png", "mimetypes/scalable/image-png"],
        ["notes.txt", "mimetypes/scalable/text-plain"], ["Invoice 2211.pdf", "mimetypes/scalable/application-pdf"], ["wallpapers", "places/scalable/folder"],
        ["budget.ods", "mimetypes/scalable/x-office-spreadsheet"], ["build.py", "mimetypes/scalable/text-x-script"],
        ["a-very-long-file-name-that-will-not-fit-on-two-lines.tar.zst", "mimetypes/scalable/package-x-generic"],
        ["Song.mp3", "mimetypes/scalable/audio-mpeg"], ["Clip.mp4", "mimetypes/scalable/video-mp4"], ["Talk.odp", "mimetypes/scalable/x-office-presentation"],
        ["Pictures", "places/scalable/folder-pictures"], ["Red", "places/scalable/folder-red"], ["unreadable.png", "no-such-picture"],
    ]
    function things(count) {
        return files.slice(0, count).map(file => ({ name: file[0], icon: icons + file[1] + ".svg", spare: icons + "mimetypes/scalable/image-png.svg" }));
    }

    Row {
        anchors.centerIn: parent
        spacing: Theme.space.s8

        StackGrid { anchors.bottom: parent.bottom; items: sheet.things(14) }
        StackGrid { anchors.bottom: parent.bottom; items: sheet.things(6) }
        StackGrid { anchors.bottom: parent.bottom; items: [] }
    }
}
