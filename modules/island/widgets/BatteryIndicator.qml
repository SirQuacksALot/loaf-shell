import QtQuick
import "../.."
import "../../.."
import "../../../services" as Services

// Dynamischer Akku-Indikator, angelehnt an GNOMEs "Battery Status"-Mockup
// (https://gitlab.gnome.org/Teams/Design/os-mockups - battery-status): statt
// zwischen ein paar festen Lucide-Batterie-Icons zu wechseln, ist die
// Kapsel selbst der Ladestand - ein echter Balken, der live mitwächst/
// -schrumpft, plus Farbe/Overlay je nach Zustand:
//   - Laden:        grün, Blitz-Overlay
//   - normal:        neutral (Theme.colors.text), Balkenlänge = Ladestand
//   - <= 20%:          Warnfarbe (gelb), sonst wie normal
//   - <= 10%:            Fehlerfarbe (rot) + "!"-Overlay
//   - <= 5%:                Fehlerfarbe, Balken komplett voll ("Kritisch,
//                            gleich aus" - siehe GNOME-Mockup: die ganze
//                            Anzeige wird rot statt nur ein schmaler Rest)
Item {
    id: root

    readonly property real percentage: Services.Battery.percentage
    readonly property bool charging: Services.Battery.charging || Services.Battery.fullyCharged
    readonly property bool available: Services.Battery.available

    readonly property bool critical: root.available && !root.charging && root.percentage <= 0.05
    readonly property bool veryLow: root.available && !root.charging && root.percentage <= 0.10
    readonly property bool low: root.available && !root.charging && root.percentage <= 0.20

    readonly property color stateColor: {
        if (!root.available) return Theme.colors.muted
        if (root.charging) return Theme.colors.success
        if (root.veryLow) return Theme.colors.error
        if (root.low) return Theme.colors.warning
        return Theme.colors.text
    }

    implicitWidth: body.width + nub.width + 1
    implicitHeight: body.height

    Rectangle {
        id: body
        width: 24
        height: 12
        radius: 3
        color: "transparent"
        border.width: 1.3
        border.color: root.stateColor

        Behavior on border.color { ColorAnimation { duration: Theme.animationDurations.short } }

        Rectangle {
            id: fill
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 2
            height: parent.height - 4
            radius: 1
            color: root.stateColor
            width: root.available
                ? Math.max(0, (body.width - 4) * (root.critical ? 1 : root.percentage))
                : 0

            Behavior on width { NumberAnimation { duration: Theme.animationDurations.normal } }
            Behavior on color { ColorAnimation { duration: Theme.animationDurations.short } }
        }

        LucideIcon {
            visible: root.charging
            anchors.centerIn: parent
            name: "zap"
            size: 8
            color: Theme.colors.background
        }

        Text {
            visible: !root.charging && root.veryLow
            anchors.centerIn: parent
            text: Localization.battery.critical
            font.bold: true
            font.pixelSize: 9
            color: Theme.colors.background
        }
    }

    Rectangle {
        id: nub
        width: 2
        height: 6
        radius: 1
        color: root.stateColor
        anchors.left: body.right
        anchors.leftMargin: 1
        anchors.verticalCenter: body.verticalCenter

        Behavior on color { ColorAnimation { duration: Theme.animationDurations.short } }
    }
}
