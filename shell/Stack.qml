import Quickshell
import Quickshell.Io
import QtQuick
import Ambrosia

// A Dock stack open on the Overlay: what Downloads shows when clicked. It
// reads the folder's newest things (and what kind each is, for its icon),
// lays them out as StackGrid draws them, and opens what is clicked: a thing
// with its own app, the button with the folder in Files.
StackGrid {
    id: stack

    // Popups.stack: { folder, edge, x, y }.
    property var request: null
    readonly property Region blurArea: Region { item: stack; radius: Theme.radius.panel }

    function read() {
        if (!visible || !request) return;
        items = [];
        loading = true;
        list.running = true;
    }
    onVisibleChanged: read()
    onRequestChanged: read()

    onOpened: index => {
        const path = items[index].path;
        Popups.close();
        Session.open(path);
    }
    onFolderOpened: {
        const folder = request.folder;
        Popups.close();
        Session.open(folder);
    }

    // A picture is its own icon; anything else wears its kind's, by the
    // icon theme's names (text/plain is text-plain, or text-x-generic).
    function iconFor(kind, path) {
        if (/^image\/(png|jpeg|gif|webp|bmp|svg\+xml)$/.test(kind))
            return "file://" + path.split("/").map(encodeURIComponent).join("/");
        if (kind === "inode/directory") return Quickshell.iconPath("folder", "inode-directory");
        const family = kind.split("/")[0];
        return Quickshell.iconPath(kind.replace("/", "-"), family === "application" ? "unknown" : family + "-x-generic");
    }

    // A line a thing, newest first: its kind, a tab, its name.
    Process {
        id: list
        command: ["sh", "-c",
            'cd "$1" 2>/dev/null && ls -t | head -n "$2" | while IFS= read -r name; do printf "%s\\t%s\\n" "$(file -b --mime-type -- "$name")" "$name"; done',
            "sh", stack.request?.folder ?? "", String(Theme.size.stack.newest)]
        stdout: StdioCollector {
            onStreamFinished: {
                const folder = stack.request?.folder ?? "";
                stack.items = text.split("\n").filter(line => line.includes("\t")).map(line => {
                    const tab = line.indexOf("\t");
                    const name = line.slice(tab + 1);
                    return { name: name, path: folder + "/" + name, icon: stack.iconFor(line.slice(0, tab), folder + "/" + name) };
                });
                stack.loading = false;
            }
        }
    }
}
