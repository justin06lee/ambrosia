pragma Singleton
import QtQml

// One pair of speakers, at a little over half.
QtObject {
    readonly property QtObject shotSpeakers: QtObject {
        readonly property bool isSink: true
        readonly property bool isStream: false
        readonly property bool ready: true
        readonly property string name: "shot.speakers"
        readonly property string nickname: "Speakers"
        readonly property string description: "Speakers"
        readonly property QtObject audio: QtObject {
            property real volume: 0.6
            property bool muted: false
        }
    }
    property QtObject defaultAudioSink: shotSpeakers
    property QtObject preferredDefaultAudioSink: shotSpeakers
    readonly property var nodes: ({ values: [shotSpeakers] })
}
