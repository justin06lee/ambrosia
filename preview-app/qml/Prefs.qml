pragma Singleton
import QtQuick
import QtCore

// What Preview's Settings window sets (Preview > Settings… on a Mac), kept
// in ~/.config/ambrosia/preview.conf and read live by every window: the
// ground behind a picture or a PDF's pages, whether pictures opened
// together share a window, what a PDF's actual size is, and whether a PDF
// opens on the page it was left at. Only what our Preview does is here (a
// Mac's has annotations' names, a picture's scale, page layouts, logical
// page numbers and 3D too).
QtObject {
    id: prefs

    // "" is Preview's own ground (Look.ground).
    property alias ground: saved.ground
    property alias separate: saved.separate
    // A PDF at actual size is as large as on paper (the screen's own
    // density); otherwise a point of the page is a point of the screen.
    property alias printout: saved.printout
    property alias lastPage: saved.lastPage

    // Where PDFs were left, by file: kept as text, the latest 200.
    property var places: ({})
    function pageFor(file) {
        const page = places[file];
        return lastPage && typeof page === "number" ? page : 0;
    }
    function remember(file, page) {
        if (!lastPage || file === "" || places[file] === page)
            return;
        const next = {};
        const names = Object.keys(places).filter(name => name !== file);
        for (const name of names.slice(Math.max(0, names.length - 199)))
            next[name] = places[name];
        if (page > 0)
            next[file] = page;
        places = next;
        saved.places = JSON.stringify(next);
    }

    property Settings store: Settings {
        id: saved
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/ambrosia/preview.conf"
        property string ground: ""
        property bool separate: false
        property bool printout: true
        property bool lastPage: true
        property string places: "{}"
    }
    Component.onCompleted: {
        try {
            const read = JSON.parse(saved.places || "{}");
            const next = {};
            for (const name of Object.keys(read)) {
                if (typeof read[name] === "number")
                    next[name] = read[name];
            }
            places = next;
        } catch (error) {
            places = {};
        }
    }
}
