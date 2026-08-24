import QtQuick
import ".."

// Basistyp für EINEN Morph-Zustand (siehe MorphContainer.qml, das
// Gegenstück, und MorphContent.qml für die Reveal-Choreographie). Zeichnet
// selbst keine Fläche (die kommt vom MorphContainer) und kümmert sich auch
// nicht ums gestaffelte Ein-/Ausblenden der einzelnen Kinder (das macht
// MorphContent, automatisch, siehe unten) - MorphItem regelt nur noch:
// bin ich der gerade aktive Zustand, ja/nein, und welche Maße soll die
// Fläche annehmen, wenn ich es werde.
//
//   // views/MusicView.qml
//   MorphItem {
//       name: "music"
//       preferredWidth: 470; preferredHeight: 108
//       required property var islandRoot
//       RowLayout { anchors.fill: parent; ... }   // landet automatisch in MorphContent
//   }
//
// "peek" (der Ruhezustand der Insel) ist NICHTS Besonderes - einfach ein
// MorphItem ohne eigenen Inhalt (siehe views/PeekView.qml); die Fläche
// selbst ist ja bereits da (siehe MorphContainer.qml), es gibt nur nichts
// draufzulegen.
Item {
    id: root

    required property string name

    // Maße, die die FLÄCHE (MorphContainer) annehmen soll, sobald dieses
    // Item aktiv ist. Dieses Item selbst füllt immer nur seinen Parent
    // (siehe anchors.fill unten) - die eigentliche Größenänderung passiert
    // eine Ebene höher, an der Fläche.
    property real preferredWidth: 100
    property real preferredHeight: 40

    // Soll die Fläche, wenn DIESES Item aktiv ist, bündig an der
    // Bildschirmkante andocken (oben eckig, "Notch"-Look) oder als
    // eigenständige Pille mit Abstand schweben (rundum abgerundet)?
    // Standard: schwebend. Nur PeekView setzt das auf false - siehe
    // MorphContainer.qml für die eigentliche Umsetzung.
    property bool floating: true

    // Nur im angedockten Zustand (floating:false) wirksam: schiebt die
    // Fläche zusätzlich UM SO VIELE Pixel in die Bildschirmkante rein
    // (nicht nur bündig damit, siehe oben) - so verschwindet ein Teil
    // davon "hinter" der Kante, statt nur flach damit abzuschließen. 0 =
    // altes Verhalten (exakt bündig). Siehe MorphContainer.qml für die
    // Vorzeichen-Logik je nach `edge`.
    property int dockedOffset: 0

    // Aussehen der Fläche, wenn DIESES Item aktiv ist - normalerweise
    // einfach das Theme, aber pro View überschreibbar (siehe z.B.
    // PeekView.qml: eigener, dunklerer "Notch"-Look mit stärkerer
    // Rundung). EIN Wert für alles: untere Ecken (immer), obere Ecken
    // (wenn floating - normal konvex rund) UND obere "Ohren" (wenn
    // angedockt, floating=false - siehe MorphContainer.qml, das dafür
    // ein Canvas statt Rectangle-Radius braucht, weil die Fläche dort
    // breiter wird als der Pillenkörper).
    property real cornerRadius: Theme.metrics.radius
    property color surfaceColor: Theme.colors.background
    property color borderColor: Theme.colors.border

    // Vom MorphContainer gesetzt: true, sobald dieses Item das aktuelle
    // Ziel ist (siehe dort für die Zeitplanung/Reihenfolge).
    property bool active: false

    property int leaveDuration: Config.leaveDuration

    // Manche Inhalte (z.B. eine reine Icon-Zeile mit IconImage-Kindern,
    // siehe dock/views/AppsView.qml) vertragen das volle Staffeln nicht
    // gut - die Icons werden asynchron geladen, und in Kombination mit
    // der Scale-Feder (Start bei scale:0.85) blieben Kacheln beobachtbar
    // unsichtbar, bis irgendein UNABHÄNGIGER Repaint (z.B. ein Drag) sie
    // "nachträglich" zum Vorschein brachte. `staggerContent: false`
    // schaltet das Pop-in komplett ab (Notlösung), `staggerScale: false`
    // ist die mildere Variante - nur Opacity fadet rein, Scale bleibt bei
    // 1 (kein Feder-Reset auf 0.85). Beide Standard: an - betrifft nur
    // Views, die es explizit ändern.
    property bool staggerContent: true
    property bool staggerScale: true

    anchors.fill: parent

    // Kinder landen automatisch in einem MorphContent (siehe dort), das
    // sie gestaffelt reinpoppen lässt, sobald dieses Item aktiv wird.
    default property alias content: contentReveal.data

    // Sichtbarkeit des GESAMTEN Items. Kein eigenes Pop/Scale mehr hier -
    // das übernimmt MorphContent pro Kind, granularer und lebendiger als
    // ein einzelner Block-Fade es könnte. Enter ist daher instant (0ms) -
    // die einzelnen Kinder erledigen die eigentliche "Erscheinen"-Optik.
    // Verschwinden bleibt ein simpler, schneller Block-Fade (kein Grund,
    // das Verlassen auch zu staffeln).
    opacity: 0
    visible: opacity > 0.001

    state: root.active ? "shown" : ""

    states: State {
        name: "shown"
        PropertyChanges { target: root; opacity: 1 }
    }

    transitions: [
        Transition {
            to: "shown"
            NumberAnimation { property: "opacity"; duration: 0 }
        },
        Transition {
            from: "shown"
            NumberAnimation { property: "opacity"; duration: root.leaveDuration; easing.type: Easing.InCubic }
        }
    ]

    MorphContent {
        id: contentReveal
        anchors.fill: parent
        enabled: root.staggerContent
        staggerScale: root.staggerScale
        revealed: root.active
    }
}
