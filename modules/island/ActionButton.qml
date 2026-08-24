import QtQuick
import ".."
import "../.."

// Kleiner, runder Icon-Button - für einfache, sofortige Aktionen (Close,
// Mute-Toggle, Notification-Glocke, Playback-Controls, ...). NIE Text,
// nur ein Icon (siehe MenuButton.qml für Text-Buttons bzw. größere
// Icon-Buttons). Hintergrund ist standardmäßig sichtbar (kleine runde
// Kachel), lässt sich aber pro Instanz abschalten (`showBackground: false`)
// für einen minimaleren, freistehenden Look.
Rectangle {
    id: root

    property string icon: "circle"
    property int iconSize: 15
    property int diameter: 26
    property bool showBackground: true
    property color background: Theme.colors.surface
    property color iconColor: Theme.colors.textMuted
    property bool available: true

    // 0 = kein Badge. Für Fälle wie die Notification-Glocke.
    property int badgeCount: 0

    // Leer = kein Tooltip.
    property string tooltip: ""

    signal tapped()

    // Ist (diameter - iconSize) ungerade, gibt es KEINE Aufteilung in zwei
    // gleich große ganzzahlige Ränder - einer landet zwangsläufig 1px größer
    // als der andere, und zwar IMMER auf derselben Seite (Math.round rundet
    // .5 konsequent auf), nie zufällig abwechselnd. Sichtbares Symptom: das
    // Icon wirkt bei genau dieser Größenkombination (z.B. 22/15) dauerhaft
    // ~1px nach rechts/unten verschoben. Fix an der Wurzel statt am Rundungs-
    // ort: diameter bei Bedarf um 1px anheben, bis die Differenz gerade ist -
    // optisch nicht wahrnehmbar, macht die Aufteilung aber IMMER exakt symmetrisch.
    readonly property int _effectiveDiameter: root.diameter + ((root.diameter - root.iconSize) % 2 !== 0 ? 1 : 0)

    width: root._effectiveDiameter
    height: root._effectiveDiameter
    radius: root._effectiveDiameter / 2
    color: root.showBackground ? root.background : "transparent"
    opacity: root.available ? 1 : 0.4

    // Tastaturfokus: activeFocusOnTab macht diesen Button Teil der
    // Fenster-weiten Tab-Kette (siehe nextItemInFocusChain()-Aufrufe in
    // den jeweiligen Root-Views - EIN zentraler Tab-Handler dort reicht,
    // statt jeden Button einzeln zu verdrahten). Der Fokusring ist ein
    // simpler Border, kein extra Overlay - Buttons sind hier durchweg
    // rund/klein, ein zusätzliches Rechteck drumrum sähe unpassend aus.
    activeFocusOnTab: root.available
    border.width: root.activeFocus ? 2 : 0
    border.color: Theme.colors.accent

    Behavior on color { ColorAnimation { duration: Theme.animationDurations.short } }

    // Hover-Highlight: eigenes, halbtransparentes Rectangle statt die
    // Basis-`color` selbst umzuschalten - funktioniert dadurch unabhängig
    // davon, ob showBackground gerade an/aus ist (transparent bleibt
    // transparent, bekommt beim Hover aber trotzdem sichtbar einen dezenten
    // Schimmer statt komplett unverändert zu bleiben).
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "#ffffff"
        opacity: (hover.hovered && root.available) ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animationDurations.short } }
    }

    LucideIcon {
        anchors.centerIn: parent
        name: root.icon
        size: root.iconSize
        color: root.iconColor
    }

    Rectangle {
        visible: root.badgeCount > 0
        width: 14
        height: 14
        radius: 7
        color: Theme.colors.accent
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: -2
        anchors.rightMargin: -4

        Text {
            anchors.centerIn: parent
            text: root.badgeCount > 9 ? Localization.actionButton.badgeOverflow : root.badgeCount
            color: Theme.colors.background
            font.pixelSize: 9
            font.bold: true
        }
    }

    TapHandler {
        enabled: root.available
        onTapped: root.tapped()
    }

    HoverHandler {
        id: hover
        cursorShape: root.available ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
    ButtonTooltip {
        target: root
        text: root.tooltip
        hovered: hover.hovered
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.tapped()
            event.accepted = true
        } else {
            // Explizit false statt weglassen - siehe MenuButton.qml für die
            // Begründung (Qt Quick liefert accepted sonst schon als true,
            // Tab käme nie beim zentralen Handler in MorphContainer.qml an).
            event.accepted = false
        }
    }
}
