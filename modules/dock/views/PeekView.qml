import "../.."

// Ruhezustand des Docks: ein leeres MorphItem, genau wie
// modules/island/views/PeekView.qml (dort das Vorbild + ausführlicher
// Kommentar). floating: false, edge: "bottom" (siehe DockShape.qml) -
// dadurch werden die OBEREN statt unteren Ecken eckig, spiegelverkehrt
// zur Insel.
MorphItem {
    id: view

    name: "peek"
    preferredWidth: 140
    preferredHeight: 12
    floating: false
    dockedOffset: 8

    surfaceColor: "black"
    borderColor: "transparent"

    required property var dockRoot
}
