import QtQuick

// Stands in for Plasma's: whether a lock key (Caps Lock) is on. Never, here.
QtObject {
    property int key
    property bool locked: false
    property bool latched: false
    property bool pressed: false
}
