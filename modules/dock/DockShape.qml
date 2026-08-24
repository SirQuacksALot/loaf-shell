import "./views" as Views
import ".."

// Verdrahtet den (jetzt allgemeinen) MorphContainer mit den Dock-Views -
// spiegelt modules/island/IslandShape.qml. edge:"bottom", weil das Dock
// am unteren statt oberen Bildschirmrand klebt (bestimmt, welche Ecken im
// angedockten "peek"-Zustand eckig sind + in welche Richtung "floating"
// von der Kante wegrutscht - siehe MorphContainer.qml). Diese Datei weiß
// NICHTS über Animation/Timing oder den Inhalt der einzelnen Zustände -
// das steckt komplett in MorphContainer.qml + den views/*.qml.
MorphContainer {
    id: shape

    required property var dockRoot

    edge: "bottom"
    anchors.horizontalCenter: parent.horizontalCenter

    target: dockRoot.revealed ? "dock" : "peek"

    // Für Dock.qml: ragt gerade ein Tooltip/Kontextmenü über die Pille
    // hinaus? Steuert dort Fenstergröße + Maske (siehe dortiger Kommentar).
    readonly property bool needsPopupSpace: appsView.popupNeedsExtraSpace

    Views.PeekView { dockRoot: shape.dockRoot }
    Views.AppsView { id: appsView; dockRoot: shape.dockRoot; popupLayer: shape.popupLayer }
}
