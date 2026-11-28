pragma Singleton
import QtQuick

// Shows the Save panel (SavePanel.qml) over a window, as a Mac's small
// Save sheet: Saving.show({ name, extension, rows, filter, save, cancel },
// window).
//   name       what the file is called to begin with, without extension
//   prompt     the name's own label when it isn't "Save As:"
//   extension  ".rtf": added to what is typed unless it ends so already;
//              or a function of the rows' values, for a format pop-up
//   folder     where it opens ("": where this app last saved, or Documents)
//   rows       pop-ups under a rule, as a Mac app's own part of its panel:
//              [{ key, label, items: [{ text, value }], current }]
//   filter     the kind as the full panel names it ("PDF (*.pdf)")
//   save       (path, values) => …: where to write, and each row's choice
//   cancel     () => …: nothing was chosen
// One panel a window; it is made anew each time and gone when it closes.
// Any other folder is Files' own panel (Places.browse), whose answer is
// the answer.
QtObject {
    id: saving

    property var panels: []
    property Component window: Component { SavePanel {} }
    // The jobs gone to the full panel, by the number they went under.
    property var browsing: ({})
    property int next: 0

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
            saving.panels = saving.panels.filter(each => each !== panel);
            panel.destroy();
        });
        panel.present();
        panel.show();
        panel.requestActivate();
    }

    // The full panel, for a job the small one hands on.
    function browse(job, folder, name, values) {
        const id = ++next;
        browsing[id] = { job: job, values: values };
        Places.browse(id, folder, name, job.filter ?? "");
    }
    property Connections answers: Connections {
        target: Places
        function onBrowsed(id, path) {
            const waiting = saving.browsing[id];
            if (!waiting)
                return;
            delete saving.browsing[id];
            if (path !== "")
                waiting.job.save(path, waiting.values);
            else if (waiting.job.cancel)
                waiting.job.cancel();
        }
    }
}
