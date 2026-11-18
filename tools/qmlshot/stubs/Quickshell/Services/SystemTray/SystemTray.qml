pragma Singleton
import QtQml

// No app has a status item. A sheet can put some in shotItems: { id, title,
// icon: a picture's URL, status, hasMenu, menu, activate(), secondaryActivate() }.
QtObject {
    property var shotItems: []
    readonly property var items: shotItems
}
