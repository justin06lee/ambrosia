pragma Singleton
import QtQuick
import QtCore
import Ambrosia
import TextEditor

// What TextEdit's Settings window sets (TextEdit > Settings… on a Mac),
// kept in ~/.config/ambrosia/textedit.conf and read live by every window:
// a new document's format, window size and fonts, whether the ruler
// shows, and how files are opened and saved. Only what our TextEdit does
// is here (no spelling, smart quotes, properties or HTML).
QtObject {
    id: prefs

    property alias rich: saved.rich
    property alias columns: saved.columns
    property alias lines: saved.lines
    // "" is the system's fixed-width font.
    property alias plainFamily: saved.plainFamily
    property alias plainSize: saved.plainSize
    property alias richFamily: saved.richFamily
    property alias richSize: saved.richSize
    property alias ruler: saved.ruler
    property alias rtfAsCode: saved.rtfAsCode
    property alias addTxt: saved.addTxt
    // "auto", "utf-8", "utf-16" or "latin1".
    property alias openEncoding: saved.openEncoding
    property alias saveEncoding: saved.saveEncoding

    readonly property string plainFont: plainFamily !== "" ? plainFamily : Theme.monoFont

    function restore() {
        rich = true;
        columns = 96;
        lines = 30;
        plainFamily = "";
        plainSize = 11;
        richFamily = "Helvetica";
        richSize = 12;
        ruler = true;
        rtfAsCode = false;
        addTxt = true;
        openEncoding = "auto";
        saveEncoding = "auto";
    }

    // A new document's window. A Mac's at 96 characters by 30 lines in its
    // own fonts is Look's plain and rich sizes; other numbers and other
    // fonts change the text's share of that in proportion (a character is
    // a digit's width, a line the font's own).
    function windowSize(rich) {
        const now = rich ? richNow : plainNow, first = rich ? richFirst : plainFirst;
        const wide = rich ? Look.richWidth : Look.plainWidth, tall = rich ? Look.richHeight : Look.plainHeight;
        const aside = 37, above = rich ? Look.viewAbove : 49;
        const across = (wide - aside) * (columns / 96) * (now.advanceWidth("0") / first.advanceWidth("0"));
        const down = (tall - above) * (lines / 30) * (now.lineSpacing / first.lineSpacing);
        return Qt.size(Math.round(aside + across), Math.round(above + down));
    }

    property Settings store: Settings {
        id: saved
        location: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation) + "/ambrosia/textedit.conf"
        property bool rich: true
        property int columns: 96
        property int lines: 30
        property string plainFamily: ""
        property real plainSize: 11
        property string richFamily: "Helvetica"
        property real richSize: 12
        property bool ruler: true
        property bool rtfAsCode: false
        property bool addTxt: true
        property string openEncoding: "auto"
        property string saveEncoding: "auto"
    }
    property FontMetrics plainFirst: FontMetrics { font.family: Theme.monoFont; font.pointSize: 11 }
    property FontMetrics plainNow: FontMetrics { font.family: prefs.plainFont; font.pointSize: prefs.plainSize }
    property FontMetrics richFirst: FontMetrics { font.family: "Helvetica"; font.pointSize: 12 }
    property FontMetrics richNow: FontMetrics { font.family: prefs.richFamily; font.pointSize: prefs.richSize }
}
