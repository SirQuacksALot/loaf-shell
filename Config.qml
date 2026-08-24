pragma Singleton
import Quickshell
import QtQuick

// Zentrale Stelle für die Timing-Werte der drei Morph-Basisklassen
// (MorphContainer/MorphItem/MorphContent, siehe modules/island/README.md) -
// Federn (spring/damping/mass/epsilon) UND feste Dauern (ms) an einem Ort
// statt über drei Dateien verstreut. Property-Namen folgen der Datei, in
// der sie verwendet werden (surface* = MorphContainer, content* =
// MorphContent). Analog zu Theme.qml (Farben/Metrics) - bewusst eine
// eigene Datei statt dort mit reinzupacken: andere Verantwortung
// (Bewegung statt Look).
Singleton {
    id: root

    // MorphContainer.qml: Feder für Breite/Höhe/Position der Fläche selbst
    // (dieselbe Feder für alle drei - soll sich wie EIN zusammenhängender
    // physischer Körper anfühlen, nicht wie drei zufällig gleichzeitig
    // laufende Animationen, siehe dortiger Kommentar).
    readonly property QtObject surfaceSpring: QtObject {
        readonly property real spring: 5
        readonly property real damping: 0.6
        readonly property real mass: 1
        readonly property real epsilon: 0.5
    }

    // MorphContainer.qml (leaveTimer) UND MorphItem.qml (eigener Opacity-
    // Fade beim Verlassen) - MÜSSEN identisch sein: Phase 1 ("leave") gilt
    // erst als abgeschlossen, wenn BEIDE abgelaufen sind (siehe
    // MorphContainer._tryActivate()). Vorher zwei unabhängige Properties
    // mit zufällig demselben Default (90) - hier jetzt strukturell
    // garantiert gleich.
    readonly property int leaveDuration: 90

    // MorphContainer.qml (surface): Radius-/Farb-Überblendung, z.B. beim
    // Docked<->Floating-Wechsel oder wenn eine View eigene Theme-Werte
    // setzt (siehe PeekView.qml).
    readonly property int surfaceCornerDuration: 180

    // MorphContent.qml: Feder fürs Scale-Pop-in der einzelnen Kinder -
    // bewusst strammer als surfaceSpring (der Inhalt soll spürbar
    // "ankommen", während die Fläche das größere, ruhigere Element bleibt).
    readonly property QtObject contentSpring: QtObject {
        readonly property real spring: 8
        readonly property real damping: 0.65
        readonly property real mass: 1
        readonly property real epsilon: 0.01
    }

    readonly property int contentEnterDuration: 110  // Opacity-Dauer pro Kind
    readonly property int contentStaggerDelay: 32    // Verzögerung zwischen aufeinanderfolgenden Kindern

    // IslandRoot.qml: wie lange ein per Hyprland-Hotkey geöffnetes Panel
    // (Control Center, Wallpaper-Picker, ...) offen bleibt, auch OHNE
    // dass die Maus je draufgeht - läuft als ganz normaler Timer ab,
    // kein dauerhaftes "Anpinnen" mehr (siehe hotkeyHeldOpen dort).
    readonly property int hotkeyOpenDuration: 3000

    // IslandRoot.qml: Gnadenfrist, bevor die Insel nach Hover-Leave
    // wieder in "peek" verschwindet (siehe hideTimer/effectiveHideDelay
    // dort - "info" hat davon abweichend IMMER 0, das bleibt hart
    // codiert, ist kein Timing zum Austesten sondern bewusstes Verhalten).
    readonly property int hideDelay: 350

    // IslandRoot.qml (idleResetTimer): manuell geöffnete Views (Music,
    // Control Center, ...) springen automatisch zurück auf "default",
    // wenn so lange gar nicht mehr gehovert wurde - das eigentliche
    // "auto close" für eine offen gelassene View.
    readonly property int viewModeIdleTimeout: 1000
}
