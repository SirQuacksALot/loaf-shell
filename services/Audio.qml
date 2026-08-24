pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Wrapper um den Standard-Audio-Sink. audio.volume/muted sind nur gültig,
// solange der Node über PwObjectTracker gebunden ("getrackt") ist.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.ready && sink.audio !== null
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : true

    // Welches Icon zum aktuellen Zustand passt (siehe icons/*.svg)
    readonly property string iconName: {
        if (!ready || muted) return "volume-x";
        if (volume < 0.01) return "volume";
        if (volume < 0.5) return "volume-1";
        return "volume-2";
    }

    function setVolume(v) {
        if (!ready) return;
        const clamped = Math.max(0, Math.min(1, v));
        sink.audio.muted = false;
        sink.audio.volume = clamped;
        root._playFeedback();
    }

    function toggleMute() {
        if (!ready) return;
        sink.audio.muted = !sink.audio.muted;
    }

    // Kurzer Klick beim Ziehen des Lautstärke-Sliders (ControlCenterView) -
    // Standard-Freedesktop-Sound-Theme-Datei, ~67ms lang. Rate-limitiert
    // per Timer statt bei jedem einzelnen Pixel-Schritt eines Drags zu
    // spielen - sonst überlappen/garbeln sich die Klicks hörbar. canberra-
    // gtk-play statt direktem paplay/pw-play auf die .oga-Datei, weil es
    // per XDG-Sound-Theme-Namen auflöst (funktioniert auch, falls das
    // System-Theme mal wechselt) und bereits installiert ist.
    // execDetached statt eines Process-Objekts, weil hier potenziell
    // mehrere kurze Aufrufe schnell hintereinander laufen - ein einzelnes,
    // wiederverwendetes Process-Objekt würde überlappende Aufrufe
    // stillschweigend verschlucken (running:true -> true ist ein No-Op).
    Timer { id: feedbackCooldown; interval: 150 }

    function _playFeedback() {
        if (feedbackCooldown.running) return;
        feedbackCooldown.restart();
        Quickshell.execDetached(["canberra-gtk-play", "-i", "audio-volume-change"]);
    }

    // Pipewire-Objekte müssen aktiv "getrackt" werden, sonst bleiben
    // audio.volume/muted ungültig.
    PwObjectTracker {
        objects: [root.sink]
    }
}
