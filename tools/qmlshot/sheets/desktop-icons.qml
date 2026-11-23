import QtQuick
import Quickshell
import "../parts"
import "../../../out/build/qmlshot/shell"

// What is in ~/Desktop as icons on the desktop: down the right edge, then
// the next column, in name order; the second one chosen. (The folder here
// is made up, so the pictures in it can't be read and wear their kind's
// icon, as an unreadable one would.)
Desk {
    Component.onCompleted: Quickshell.shotRun = command => {
        if (command[0] === "mkdir") return "";
        if (command[0] === "sh" && command[2].includes("stat -c")) return [
            "1795000300\tinode/directory\tuntitled folder",
            "1795000200\timage/png\tScreenshot 2026-11-18 at 09.41.12.png",
            "1795000100\tapplication/pdf\tInvoice 2211.pdf",
            "1795000000\ttext/plain\tnotes.txt",
            "1794000000\tinode/directory\tProjects",
            "1793000000\tapplication/zstd\ta-very-long-file-name-that-will-not-fit-on-two-lines.tar.zst",
            "1792000000\taudio/mpeg\tSong.mp3",
            "1791000000\tapplication/vnd.oasis.opendocument.spreadsheet\tbudget.ods",
            "1790000000\ttext/x-python\tbuild.py",
        ].join("\n");
        return undefined;
    }
    then: () => {
        shotPointer.press(1378, 36 + 112 + 40);
        shotPointer.release(1378, 36 + 112 + 40);
    }
}
