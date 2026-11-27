import QtQuick
import DiskUtility
import "disks.mjs" as Logic

// Disk Utility itself: its one window, and an Info window for each disk or
// volume asked about. It goes when its window does, as a Mac's.
QtObject {
    id: main

    property DiskUtilityWindow window: DiskUtilityWindow {
        onClosing: Qt.callLater(Qt.quit)
        onInfoRequested: (key) => main.info(key)
    }
    property var infos: []
    property Component maker: Component { InfoWindow {} }

    function info(key) {
        const have = infos.find(w => w.key === key);
        if (have) {
            App.activate(have);
            return;
        }
        const made = maker.createObject(null, { key: key });
        if (!made) {
            console.warn("Disk Utility: no Info window", maker.errorString());
            return;
        }
        // What it says follows the disks; when its thing is gone, so is it.
        made.name = Qt.binding(() => Logic.find(main.window.all, made.key)?.name ?? made.name);
        made.rows = Qt.binding(() => Logic.info(main.window.all, Logic.find(main.window.all, made.key)));
        infos = infos.concat([made]);
        made.closing.connect(() => main.closed(made));
    }
    function closed(which) {
        infos = infos.filter(w => w !== which);
        which.destroy(200);
    }

    property Connections disks: Connections {
        target: Disks
        function onChanged() {
            for (const open of main.infos) {
                if (Logic.find(main.window.all, open.key) === null)
                    open.close();
            }
        }
    }
    property Connections app: Connections {
        target: App
        function onOpenRequested(files) {
            main.window.visible = true;
            App.activate(main.window);
            for (const file of files)
                Disks.attach(file);
        }
    }

    Component.onCompleted: {
        main.window.visible = true;
        for (const file of App.files)
            Disks.attach(file);
    }
}
