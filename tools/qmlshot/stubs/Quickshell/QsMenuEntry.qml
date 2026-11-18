import QtQml

// One row of such a menu, and the handle of its submenu.
QsMenuHandle {
    property string text
    property bool enabled: true
    property bool isSeparator: false
    property string icon
    property int buttonType: 0
    property int checkState: Qt.Unchecked
    readonly property bool hasChildren: shotChildren.length > 0
    // Our Quickshell build's addition: the row's key, as DBusMenu gives it.
    property var shortcut: []
    signal triggered()
}
