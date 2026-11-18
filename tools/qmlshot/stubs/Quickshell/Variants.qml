import QtQml

// One of what it holds for each thing in `model`, given as `modelData`.
QtObject {
    id: variants

    property var model: []
    default property Component delegate
    property var instances: []
    property bool ready: false

    function rebuild() {
        for (const each of instances) each.destroy();
        const made = [];
        const list = model ?? [];
        for (let i = 0; i < list.length; i++) {
            const one = delegate.createObject(variants, { modelData: list[i] });
            if (one) made.push(one);
            else console.warn("Variants:", delegate.errorString());
        }
        instances = made;
    }
    onModelChanged: if (ready) rebuild()
    Component.onCompleted: {
        ready = true;
        rebuild();
    }
}
