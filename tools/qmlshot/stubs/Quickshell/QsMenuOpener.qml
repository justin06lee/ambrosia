import QtQml
import Quickshell

// The rows of a menu handle, as a model that also answers to `values`.
QtObject {
    id: opener

    property QsMenuHandle menu: null
    readonly property ShotObjectModel children: ShotObjectModel {
        values: opener.menu?.shotChildren ?? []
    }
}
