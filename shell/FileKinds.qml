pragma Singleton
import Quickshell
import QtQuick

// The icon a file wears where the shell shows files (a Dock stack, the
// desktop), from its kind as `file --mime-type` names it.
Singleton {
    // Pictures Qt can draw are their own icons.
    readonly property var pictures: /^image\/(png|jpeg|gif|webp|bmp|svg\+xml)$/

    function url(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }
    // By the icon theme's names: text/plain is text-plain, or text-x-generic.
    function icon(kind) {
        if (kind === "inode/directory") return Quickshell.iconPath("folder", "inode-directory");
        const family = kind.split("/")[0];
        return Quickshell.iconPath(kind.replace("/", "-"), family === "application" ? "unknown" : family + "-x-generic");
    }
    function isPicture(kind) {
        return pictures.test(kind);
    }
    function iconFor(kind, path) {
        return isPicture(kind) ? url(path) : icon(kind);
    }
}
