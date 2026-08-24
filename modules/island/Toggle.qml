import QtQuick
import ".."
import "../.."

// An/Aus-Schalter (Kachel + gleitender Kreis) - für WifiView/BluetoothView.
// Angelehnt an https://github.com/s3rven/silere-shell, aber komplett
// rund statt nur abgerundet-rechteckig, passend zum Rest der App
// (ActionButton ist z.B. auch komplett kreisrund).
Item {
    id: root

    property bool checked: false
    property bool available: true
    property int trackWidth: 44
    property int trackHeight: 24
    property int knobMargin: 3

    // Leer = kein Tooltip.
    property string tooltip: ""

    signal toggled()

    implicitWidth: root.trackWidth
    implicitHeight: root.trackHeight
    opacity: root.available ? 1 : 0.4

    // Siehe ActionButton.qml für die Erklärung des Musters (Tab-Kette +
    // Fokusring + Enter/Space-Aktivierung + Tooltip). Fokusring liegt hier
    // auf einem eigenen Rahmen statt auf track selbst, da dessen
    // border.width/color schon fürs "aus"-Aussehen genutzt wird.
    activeFocusOnTab: root.available

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.colors.accent : Theme.colors.surface
        border.width: root.checked ? 0 : 1
        border.color: Theme.colors.borderSurface

        Behavior on color { ColorAnimation { duration: Theme.animationDurations.short } }

        // Hover-Highlight: siehe ActionButton.qml für die Begründung
        // (eigenes halbtransparentes Rectangle statt die Basis-`color`
        // selbst umzuschalten). Kind von `track` statt von root, damit es
        // automatisch dessen Rundung übernimmt.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "#ffffff"
            opacity: (hover.hovered && root.available) ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animationDurations.short } }
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: height / 2
        color: "transparent"
        visible: root.activeFocus
        border.width: 2
        border.color: Theme.colors.accent
    }

    Rectangle {
        id: knob
        width: root.trackHeight - root.knobMargin * 2
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.trackWidth - width - root.knobMargin : root.knobMargin
        color: root.checked ? Theme.colors.background : Theme.colors.textMuted

        Behavior on x { NumberAnimation { duration: Theme.animationDurations.normal; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Theme.animationDurations.short } }
    }

    TapHandler {
        enabled: root.available
        onTapped: root.toggled()
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
            root.toggled()
            event.accepted = true
        } else {
            // Explizit false statt weglassen - siehe MenuButton.qml für die
            // Begründung (Qt Quick liefert accepted sonst schon als true,
            // Tab käme nie beim zentralen Handler in MorphContainer.qml an).
            event.accepted = false
        }
    }
}
