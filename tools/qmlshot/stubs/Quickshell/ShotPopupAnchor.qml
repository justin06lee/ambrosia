import QtQuick

// A popup's `anchor`: the window and the spot on it that it hangs from.
QtObject {
    property QtObject window: null
    property Item item: null
    property ShotRect rect: ShotRect {}
    property int edges: 0
    property int gravity: 0
    property int adjustment: 0
}
