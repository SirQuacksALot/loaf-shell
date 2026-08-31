import ".."
import "../.."
import "./views" as Views

// Instanziiert den MorphContainer mit allen Ansichten als MorphItem-
// Kindern. Diese Datei weiß NICHTS über Animation/Timing - das steckt
// komplett in MorphContainer.qml + MorphItem.qml. Hier steht nur, WAS es
// an Ansichten gibt und WORAN sich der Container orientiert (target).
//
// import "..": MorphContainer liegt jetzt in modules/ (ein Level über
// island/, seit es allgemein nutzbar gemacht wurde - siehe dortiger
// Kommentar) - "../.." allein (Repo-Root, für eventuelle Theme-Zugriffe)
// hätte das NICHT gefunden, genau das war der Bug, der stundenlang als
// "MorphContainer is not a type" auftauchte.
MorphContainer {
    id: shape

    required property var islandRoot

    edge: "top"

    // Kein anchors.top mehr - die y-Position ist jetzt Teil des Morphs
    // selbst (angedockt vs. schwebend, siehe MorphContainer.qml) und wird
    // dort direkt gesetzt/animiert. Ein zusätzliches anchors.top hier
    // würde damit kollidieren.
    anchors.horizontalCenter: parent.horizontalCenter

    target: islandRoot.effectiveTarget

    onEscapePressed: islandRoot.closeView()

    Views.PeekView { islandRoot: shape.islandRoot }
    Views.DefaultView { islandRoot: shape.islandRoot }
    Views.InfoView { islandRoot: shape.islandRoot }
    Views.NotifyView { islandRoot: shape.islandRoot }
    Views.ControlCenterView { islandRoot: shape.islandRoot }
    Views.WifiView { islandRoot: shape.islandRoot }
    Views.BluetoothView { islandRoot: shape.islandRoot }
    Views.VpnView { islandRoot: shape.islandRoot }
    Views.PowerMenuView { islandRoot: shape.islandRoot }
    Views.GithubView { islandRoot: shape.islandRoot }
    Views.WallpaperView { islandRoot: shape.islandRoot }
    Views.ClipboardView { islandRoot: shape.islandRoot }
    Views.AudioSourceView { islandRoot: shape.islandRoot }
}
