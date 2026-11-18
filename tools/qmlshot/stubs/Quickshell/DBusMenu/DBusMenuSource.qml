import QtQml
import Quickshell

// An app's menus, from Quickshell.shotMenus: under the app's id (which
// stands for its bus name), a list of rows, each a title, "-" for a
// separator, or { text, children, enabled, checkState, shortcut }.
QsMenuHandle {
    id: source

    property string service
    property string path
    property Component shotEntry: Component { QsMenuEntry {} }

    function shotBuild(rows) {
        return (rows ?? []).map(row => {
            if (row === "-") return shotEntry.createObject(source, { isSeparator: true });
            if (typeof row === "string") return shotEntry.createObject(source, { text: row });
            const fields = Object.assign({}, row);
            delete fields.children;
            const entry = shotEntry.createObject(source, fields);
            entry.shotChildren = shotBuild(row.children);
            return entry;
        });
    }
    shotChildren: shotBuild(Quickshell.shotMenus[service])
}
