import Quickshell
import Quickshell.Wayland
import QtQuick
import ".."

// Optisch abgerundete Bildschirmecken - vier winzige, komplett
// klickdurchlässige Overlay-Fenster (eins pro Ecke), die einen schwarzen
// Viertelkreis-Rahmen über die eigentlich rechteckige Bildschirmecke
// legen. Reine Optik, kein echtes Fenstermanagement-Feature - Hyprland
// kennt keine "runden Bildschirmecken", das hier täuscht sie nur vor
// (bekannter Trick, macht z.B. auch hyprland-rounded-corners so).
//
// Dieselbe SVG-"Rechteck minus Kreis"-Maskentechnik wie die
// Thumbnail-Eckenmasken in island/views/WallpaperView.qml - dort klein
// und farbig fürs Thumbnail, hier großflächig und schwarz für die
// Bildschirmecke. Kreis-Mittelpunkt liegt jeweils am GEGENÜBERLIEGENDEN
// Eckpunkt des quadratischen Fensters (zur Bildschirmmitte hin) - exakt
// der Punkt, um den eine echte Rundung ihren Bogen zentrieren würde.
Scope {
    id: root

    required property var screen

    // Frei einstellbar - je größer, desto "runder" wirkt die Ecke.
    property int size: 12
    property color color: "black"

    Variants {
        // top/bottom/left/right: welche PanelWindow-Anker diese Ecke
        // bilden. cx/cy: wo (als Vielfaches von size) der Kreis-
        // Mittelpunkt für die Maske liegt - siehe Kommentar oben.
        model: [
            { top: true,  bottom: false, left: true,  right: false, cx: 1, cy: 1 },  // oben links
            { top: true,  bottom: false, left: false, right: true,  cx: 0, cy: 1 },  // oben rechts
            { top: false, bottom: true,  left: true,  right: false, cx: 1, cy: 0 },  // unten links
            { top: false, bottom: true,  left: false, right: true,  cx: 0, cy: 0 }   // unten rechts
        ]

        delegate: Component {
            PanelWindow {
                id: corner
                required property var modelData

                screen: root.screen
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                // Overlay - immer sichtbar, auch über maximierten/
                // fullscreen Fenstern (Sinn der Übung).
                WlrLayershell.layer: WlrLayer.Overlay
                // Leere Region = null Fläche akzeptiert Eingaben - macht
                // das Fenster komplett klickdurchlässig, reine Deko darf
                // nie irgendwas darunter blockieren.
                mask: Region {}

                anchors {
                    top: corner.modelData.top
                    bottom: corner.modelData.bottom
                    left: corner.modelData.left
                    right: corner.modelData.right
                }
                implicitWidth: root.size
                implicitHeight: root.size

                Image {
                    anchors.fill: parent
                    smooth: true
                    source: "data:image/svg+xml;utf8," + encodeURIComponent(
                        '<svg xmlns="http://www.w3.org/2000/svg" width="' + root.size + '" height="' + root.size + '">' +
                        '<mask id="m"><rect width="' + root.size + '" height="' + root.size + '" fill="white"/>' +
                        '<circle cx="' + (corner.modelData.cx * root.size) + '" cy="' + (corner.modelData.cy * root.size) + '" r="' + root.size + '" fill="black"/></mask>' +
                        '<rect width="' + root.size + '" height="' + root.size + '" fill="' + root.color + '" mask="url(#m)"/></svg>'
                    )
                }
            }
        }
    }
}
