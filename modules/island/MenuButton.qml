import QtQuick
import ".."
import "../.."

// Größerer Button, für Aktionen mit mehr Gewicht (Toggles im Control
// Center, Power-Menu, Shortcuts zu anderen Views, ...). Zeigt IMMER
// entweder ein Icon ODER ein Label - nie beides gleichzeitig
// (`showLabel`, Standard: false = Icon-Modus). Welcher der beiden Modi
// gerade aktiv ist, darf sich auch zur Laufzeit ändern (siehe
// PowerMenuView.qml: wechselt beim Antippen kurz auf den Text "Sicher?").
// Für einen reinen Text-Link ohne Kachel-Optik `showBackground: false`
// setzen (siehe "Alle löschen" in InfoView.qml).
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property bool showLabel: false

    property bool active: false
    property bool available: true
    property bool showBackground: true

    property int iconSize: 20
    property int contentPadding: 14

    property color activeColor: Theme.colors.accent
    property color inactiveColor: Theme.colors.surface
    property color activeContentColor: Theme.colors.background
    property color inactiveContentColor: root.showLabel ? Theme.colors.accent : Theme.colors.textMuted

    // Leer = kein Tooltip.
    property string tooltip: ""

    signal tapped()

    implicitWidth: (root.showLabel ? labelItem.implicitWidth : iconItem.width) + root.contentPadding * 2
    implicitHeight: (root.showLabel ? labelItem.implicitHeight : iconItem.height) + root.contentPadding

    radius: 12
    color: root.showBackground ? (root.active ? root.activeColor : root.inactiveColor) : "transparent"
    opacity: root.available ? 1 : 0.4

    // Siehe ActionButton.qml für die Erklärung des Musters (Tab-Kette +
    // Enter/Space-Aktivierung + Tooltip). Der Fokusring selbst weicht
    // bewusst vom dortigen einfachen Inset-Border ab (siehe focusRing
    // unten) - bei aktivem Toggle (root.active) ist der Hintergrund hier
    // selbst schon Theme.colors.accent, ein Border in derselben Farbe INNEN
    // auf der Fläche wäre unsichtbar bzw. bräuchte eine zweite Sonderfarbe
    // je nach Zustand (beides schon ausprobiert, beides unbefriedigend).
    activeFocusOnTab: root.available

    Behavior on color { ColorAnimation { duration: Theme.animationDurations.short } }

    // Fokusring als eigenständiges, nach AUSSEN versetztes Rechteck statt
    // Border auf root selbst - sitzt dadurch immer auf dem Grund HINTER dem
    // Button (Insel-/Panel-Hintergrund), nie auf der Button-Füllfarbe
    // selbst. Funktioniert dadurch unabhängig davon, ob root gerade
    // Theme.colors.accent, .surface oder transparent ist - keine
    // Fallunterscheidung nötig, kein Kontrastproblem mehr möglich.
    Rectangle {
        visible: root.activeFocus
        anchors.fill: parent
        anchors.margins: -3
        radius: root.radius + 3
        color: "transparent"
        border.width: 2
        border.color: Theme.colors.accent
    }

    // Hover-Highlight: eigenes, halbtransparentes Rectangle statt die
    // Basis-`color` selbst umzuschalten - funktioniert dadurch unabhängig
    // vom aktuellen active/showBackground-Zustand (siehe ActionButton.qml
    // für dieselbe Begründung).
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "#ffffff"
        opacity: (hover.hovered && root.available) ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animationDurations.short } }
    }

    LucideIcon {
        id: iconItem
        visible: !root.showLabel
        anchors.centerIn: parent
        name: root.icon
        size: root.iconSize
        color: root.active ? root.activeContentColor : root.inactiveContentColor
    }

    Text {
        id: labelItem
        visible: root.showLabel
        anchors.left: parent.left
        anchors.leftMargin: root.contentPadding
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: root.active ? root.activeContentColor : root.inactiveContentColor
        font.family: Theme.font.family
        font.pixelSize: Theme.font.size - 1
        font.bold: true
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
            // WICHTIG: explizit false, nicht einfach weglassen. Qt Quick
            // liefert KeyEvent.accepted standardmäßig bereits als true an
            // JEDES Item mit einem Keys.onPressed-Handler, unabhängig davon,
            // ob der Handler-Body überhaupt etwas tut - ohne dieses "else"
            // wäre z.B. Tab, sobald IRGENDEIN Button hier den Fokus hat,
            // automatisch "behandelt" und würde NIE beim zentralen
            // Tab-Handler in MorphContainer.qml ankommen (live beobachtet:
            // der allererste Tab-Druck sprang noch zum ersten Button, jeder
            // weitere Tab-Druck tat gar nichts mehr).
            event.accepted = false
        }
    }
}
