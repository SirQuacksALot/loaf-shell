pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Wrapper um Quickshells MPRIS-Client. Wählt automatisch einen "aktiven"
// Player (bevorzugt einen, der gerade spielt) und rechnet die
// Wiedergabeposition client-seitig glatt - MPRIS-Player melden Position
// nicht kontinuierlich, nur bei Sprüngen/Play/Pause.
Singleton {
    id: root

    readonly property var activePlayer: {
        const players = Mpris.players.values;
        for (const p of players) if (p.isPlaying) return p;
        for (const p of players) if (p.canControl) return p;
        return players.length > 0 ? players[0] : null;
    }

    readonly property bool available: activePlayer !== null
    readonly property bool playing: available && activePlayer.isPlaying
    readonly property string title: available ? activePlayer.trackTitle : ""
    readonly property string artist: available ? activePlayer.trackArtist : ""
    readonly property string album: available ? activePlayer.trackAlbum : ""
    readonly property string artUrl: available ? activePlayer.trackArtUrl : ""
    readonly property real length: available ? activePlayer.length : 0
    readonly property bool canGoNext: available && activePlayer.canGoNext
    readonly property bool canGoPrevious: available && activePlayer.canGoPrevious
    readonly property bool canTogglePlaying: available && activePlayer.canTogglePlaying
    readonly property bool canSeek: available && activePlayer.canSeek

    // Client-seitig hochgerechnete Position, ~4x/Sekunde aktualisiert.
    // Siehe syncAnchor()/Timer weiter unten.
    property real positionAnchor: 0
    property real anchorTimeMs: 0
    property real smoothPosition: 0

    function syncAnchor() {
        root.positionAnchor = root.available ? root.activePlayer.position : 0;
        root.anchorTimeMs = Date.now();
        root.smoothPosition = root.positionAnchor;
    }

    function toggle() { if (root.canTogglePlaying) root.activePlayer.togglePlaying(); }
    function next() { if (root.canGoNext) root.activePlayer.next(); }
    function previous() { if (root.canGoPrevious) root.activePlayer.previous(); }

    function seekTo(seconds) {
        if (!root.canSeek || root.length <= 0) return;
        root.activePlayer.position = Math.max(0, Math.min(seconds, root.length));
        root.syncAnchor();
    }

    function formatTime(seconds) {
        if (!seconds || seconds < 0) return "0:00";
        const total = Math.floor(seconds);
        const m = Math.floor(total / 60);
        const s = total % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    onActivePlayerChanged: root.syncAnchor()

    Connections {
        target: root.activePlayer
        function onPositionChanged() { root.syncAnchor() }
        function onTrackTitleChanged() { root.syncAnchor() }
        function onIsPlayingChanged() { root.syncAnchor() }
    }

    Timer {
        interval: 250
        running: root.playing
        repeat: true
        onTriggered: {
            const elapsed = (Date.now() - root.anchorTimeMs) / 1000;
            const projected = root.positionAnchor + elapsed;
            root.smoothPosition = root.length > 0 ? Math.min(projected, root.length) : projected;
        }
    }
}
