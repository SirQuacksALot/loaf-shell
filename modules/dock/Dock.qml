import Quickshell
import Quickshell.Wayland
import QtQuick
import "."

// Fenster + Zustand: reveal-Logik (Hover-Trigger unten, Auto-Hide) - WIE
// das Dock animiert/aussieht steckt jetzt komplett in DockShape.qml +
// MorphContainer.qml (siehe dort), spiegelt modules/island/IslandRoot.qml.
Scope {
    id: root

    required property var screen

    // --- Einstellungen ---
    property int triggerHeight: 6
    property int hideDelay: 350
    property int expandedHeight: 56
    property int iconBoxSize: 44
    property int iconSize: 30

    // --- Status ---
    property bool triggerHovered: false
    property bool contentHovered: false
    property bool revealed: false

    onTriggerHoveredChanged: updateVisibility()
    onContentHoveredChanged: updateVisibility()


    function updateVisibility() {
        if (triggerHovered || contentHovered) {
            hideTimer.stop()
            revealed = true
        } else {
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: root.hideDelay
        onTriggered: root.revealed = false
    }

    // 1) Hover-Trigger an der untersten Bildschirmkante
    PanelWindow {
        id: triggerZone
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay

        anchors { bottom: true; left: true; right: true }
        implicitHeight: root.triggerHeight

        HoverHandler {
            onHoveredChanged: root.triggerHovered = hovered
        }
    }

    // 2) Das Dock - immer voll geladen (kein Loader), aus demselben Grund
    // wie bei der Insel: kein asynchrones Nachladen mitten in der ersten
    // Animation.
    PanelWindow {
        id: dockWindow
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay

        anchors { bottom: true; left: true; right: true }

        // Fix statt reaktiv an die animierte Höhe gebunden - siehe
        // IslandRoot.qml für die ausführliche Begründung (natives
        // Wayland-Resize bei jedem Animationsframe war die Hauptursache
        // fürs Stottern, hier vorher via `Behavior on implicitHeight`
        // direkt auf dem PanelWindow genauso ein Problem, nur nie
        // behoben, weil's beim Dock weniger auffiel). popupHeadroom ist
        // hier bewusst IMMER mit drin (nicht nur bei Bedarf) - ein Versuch,
        // das nur bei sichtbarem Tooltip/Kontextmenü dazuzuschalten, löste
        // GENAU das native Resize aus: die Fläche wuchs, der Mauszeiger war
        // kurz "draußen", Hover ging verloren, Tooltip verschwand wieder,
        // Fenster schrumpfte zurück, Maus war wieder drin - Endlosschleife
        // ("das Dock hüpft"). Die shape selbst bleibt trotzdem an der
        // Bildschirmkante kleben (MorphContainer.y hängt an parent.height,
        // gleicht das aus) - der zusätzliche Platz ist einfach permanent
        // ungenutzter, transparenter Raum darüber, bis ihn ein Tooltip/
        // Kontextmenü braucht.
        readonly property int popupHeadroom: 90
        implicitHeight: shape.maxContentHeight + shape.floatingGap + 8 + popupHeadroom

        // Zweite, zusätzliche Region: der Streifen ÜBER der Pille, in dem
        // Tooltips/Kontextmenü rendern - nur bei Bedarf non-zero (siehe
        // popupHeadroom oben), sonst bleibt die Maske exakt wie vorher auf
        // die Pille selbst beschränkt (kein dauerhaft blockierter Bereich
        // über dem Dock, siehe Kommentar unten zu Klicks/Durchreichen).
        mask: Region {
            item: shape
            Region {
                x: 0
                y: 0
                width: shape.needsPopupSpace ? dockWindow.width : 0
                height: shape.needsPopupSpace ? dockWindow.popupHeadroom : 0
            }
        }

        HoverHandler {
            onHoveredChanged: root.contentHovered = hovered
        }

        DockShape {
            id: shape
            dockRoot: root
        }
    }
}
