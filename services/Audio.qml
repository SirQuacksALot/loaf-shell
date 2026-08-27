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

    readonly property PwNode source: Pipewire.defaultAudioSource

    // Alle wählbaren Ausgabe-/Eingabegeräte für die Geräteauswahl in
    // AudioSourceView - Streams (App-Lautstärkeregler wie "Firefox",
    // "Discord") sind bewusst raus, das sind keine Geräte. Für Ausgabe
    // reicht die eigene `isSink`-Property des Node; ein analoges
    // `isSource` gibt es nicht, daher dort über die Type-Flags gefiltert.
    //
    // WICHTIG: exakter Vergleich (=== statt reinem Truthy-Check auf
    // `& PwNodeType.AudioSource`) - Pipewire.nodes enthält NICHT nur
    // Audio-Nodes, sondern z.B. auch Kamera-Nodes (media.class
    // "Video/Source", hier: die ipu6-Kamera mit satten 14 v4l2-Nodes für
    // ihre verschiedenen Capture-Modi). VideoSource und AudioSource
    // teilen sich offenbar das "Source"-Bit - ein bloßes `& AudioSource`
    // ist dadurch für JEDEN Source-Node wahr, Video eingeschlossen, live
    // beobachtet als "ipu6 (V4L2)" x-fach in der Eingabe-Liste. Erst der
    // Vergleich auf Gleichheit mit der VOLLEN Maske schließt das aus.
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    readonly property var inputs: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && (n.type & PwNodeType.AudioSource) === PwNodeType.AudioSource)

    // description ist meist der "hübsche" Gerätename (z.B. "Family 17h HD
    // Audio Controller"), nickname/name sind rohe Pipewire-Bezeichner als
    // Fallback, falls description mal leer ist.
    function labelFor(node) {
        return node.description || node.nickname || node.name;
    }

    // Setzt NUR den "gewünschten" Default (preferredDefaultAudioSink/
    // -Source) - Pipewire/WirePlumber entscheiden am Ende selbst, welcher
    // Node tatsächlich aktiv ist (z.B. falls das gewählte Gerät gerade
    // nicht verfügbar ist), dieselbe Indirektion wie bei echten
    // Desktop-Sound-Einstellungen.
    function setDefaultOutput(node) {
        if (!node) return;
        Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultInput(node) {
        if (!node) return;
        Pipewire.preferredDefaultAudioSource = node;
    }

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
