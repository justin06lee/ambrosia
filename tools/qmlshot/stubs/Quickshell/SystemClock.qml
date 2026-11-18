import QtQml

// The time stands still in a picture: 9:41 on the day the sheets were
// first drawn, so two runs draw the same clock.
QtObject {
    enum Precision { Hours, Minutes, Seconds }

    property int precision: 2
    property bool enabled: true
    readonly property date date: new Date(2026, 10, 18, 9, 41, 0)
    readonly property int hours: 9
    readonly property int minutes: 41
    readonly property int seconds: 0
}
