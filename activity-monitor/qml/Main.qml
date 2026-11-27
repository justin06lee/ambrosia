import QtQuick
import ActivityMonitor

// Activity Monitor itself: its one window, and an inspector for each
// process asked about (the one already open for a process comes forward
// instead). Closing the window ends it, inspectors and all.
QtObject {
    id: main

    property MonitorWindow window: MonitorWindow {
        onInspectRequested: (pid) => main.inspect(pid)
        onClosing: Qt.quit()
    }
    property var inspectors: []
    property Component maker: Component { InspectorWindow {} }

    function inspect(pid) {
        if (pid < 0)
            return;
        const have = inspectors.find(w => w.pid === pid);
        if (have) {
            App.activate(have);
            return;
        }
        const made = maker.createObject(null, { pid: pid, monitor: main.window });
        if (!made) {
            console.warn("Activity Monitor: no inspector for", pid, maker.errorString());
            return;
        }
        inspectors = inspectors.concat([made]);
        made.closing.connect(() => main.closed(made));
        made.inspectRequested.connect((other) => main.inspect(other));
    }
    function closed(which) {
        inspectors = inspectors.filter(w => w !== which);
        which.destroy(200);
    }

    property Connections app: Connections {
        target: App
        function onShowRequested() {
            App.activate(main.window);
        }
    }

    Component.onCompleted: if (App.inspect >= 0) inspect(App.inspect)
}
