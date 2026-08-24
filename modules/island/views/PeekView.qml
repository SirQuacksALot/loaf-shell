import ".."
import "../.."

// Ruhezustand der Insel: einfach ein leeres MorphItem. Kein Sonderfall,
// keine eigene Optik-Logik irgendwo anders im Baum - siehe
// MorphContainer.qml/MorphItem.qml. Einzige Besonderheit: floating=false -
// das ist der einzige Zustand, der bündig/angedockt an der Bildschirmkante
// sitzt (alle anderen Views schweben, siehe dortiger Kommentar zu "floating").
MorphItem {
    id: view

    name: "peek"
    preferredWidth: 150
    preferredHeight: 12
    floating: false
    dockedOffset: 8

    surfaceColor: "black"
    borderColor: "black"

    required property var islandRoot
}
