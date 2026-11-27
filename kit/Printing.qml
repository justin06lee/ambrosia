pragma Singleton
import QtQuick

// Shows the Print panel (PrintPanel.qml) over a window, as a Mac's sheet:
// Printing.show({ title, make: (file, size) => …, save: () => … }, window)
// for a document the app writes as a PDF for the paper chosen (`size` in
// points), or { title, file } for a PDF as it is. One panel a window; it
// is made anew each time and gone when it closes. What it asks of the
// system is printing.h's Cups.
QtObject {
    id: printing

    property var panels: []
    property Component window: Component { PrintPanel {} }

    function show(job, over) {
        const up = panels.find(each => each.transientParent === over);
        if (up) {
            up.raise();
            up.requestActivate();
            return;
        }
        const panel = window.createObject(null, { job: job, transientParent: over });
        panels = panels.concat([panel]);
        panel.visibleChanged.connect(() => {
            if (panel.visible)
                return;
            printing.panels = printing.panels.filter(each => each !== panel);
            panel.destroy();
        });
        panel.present();
        panel.show();
        panel.requestActivate();
    }
}
