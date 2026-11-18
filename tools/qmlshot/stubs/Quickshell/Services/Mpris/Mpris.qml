pragma Singleton
import QtQml

// Nothing playing. A sheet can put players in shotPlayers: { identity,
// trackTitle, trackArtist, trackArtUrl, isPlaying, canTogglePlaying, … }.
QtObject {
    property var shotPlayers: []
    readonly property var players: ({ values: shotPlayers })
}
