import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "widgets" as Widgets
import "../../services" as Services

// Wiederverwendbarer Kopf für JEDE View außer InfoView (hat ihre eigene,
// erweiterte erste Zeile - Akku/Verbindung UND Shortcuts zu Control
// Center/Power statt eines Schließen-Buttons, siehe dortiger Kommentar)
// und NotifyView (kein Header, das Popup IST der Inhalt). Immer dasselbe
// Bild: links Akku + Verbindung als Quick-Info (genau wie in InfoView.qml,
// die Tooltip-Logik dafür lebt jetzt hier statt in jeder View einzeln),
// rechts der Schließen-Button. Ersetzt die vorher pro View leicht
// unterschiedlichen (und zeitweise ganz auseinandergelaufenen) Kopfzeilen
// - eine einzige Stelle für "wie sieht der Kopf einer View aus".
//
// View-spezifische Kontrollen (WLAN/Bluetooth-Toggle, Zwischenablage-
// Leeren-Button, ...) gehören NICHT hierher - die bekommen ihre eigene
// Zeile direkt darunter (siehe WifiView.qml/BluetoothView.qml/
// ClipboardView.qml). Sonst würde dieser Header doch wieder pro View
// unterschiedlich, genau das Problem, das er lösen soll.
//
//   // views/MeinFeatureView.qml
//   ColumnLayout {
//       anchors.fill: parent
//       anchors.margins: 16
//       spacing: 14
//
//       ViewHeader { islandRoot: view.islandRoot }
//       // ... eigener Inhalt
//   }
RowLayout {
    id: root

    required property var islandRoot

    Layout.fillWidth: true
    spacing: 14

    // Akku-Tooltip: Prozent + (falls verfügbar) Restzeit bis leer/voll -
    // siehe services/Battery.qml für formatDuration()/timeToEmpty/-Full.
    readonly property string batteryTooltip: {
        if (!Services.Battery.available) return Localization.viewHeader.noBattery
        const pct = Math.round(Services.Battery.percentage * 100) + Localization.common.percent
        if (Services.Battery.fullyCharged) return pct + Localization.viewHeader.batteryFull
        if (Services.Battery.charging) {
            const eta = Services.Battery.formatDuration(Services.Battery.timeToFull)
            return pct + Localization.viewHeader.batteryCharging + (eta ? Localization.viewHeader.batteryRemaining + eta + Localization.viewHeader.batteryUntilFull : "")
        }
        const eta = Services.Battery.formatDuration(Services.Battery.timeToEmpty)
        return pct + (eta ? Localization.viewHeader.batteryRemaining + eta : "")
    }

    // Verbindungs-Tooltip: WLAN-Name + Signalstärke, Ethernet-Name, oder
    // "nicht verbunden" - siehe services/Network.qml.
    readonly property string networkTooltip: {
        if (Services.Network.kind === "wifi") return Localization.viewHeader.wifiPrefix + Services.Network.connectionName + " (" + Services.Network.signalStrength + Localization.common.percent + ")"
        if (Services.Network.kind === "ethernet") return Localization.viewHeader.ethernetPrefix + Services.Network.connectionName
        return Localization.viewHeader.notConnected
    }

    // Weder Battery- noch Network-Indikator sind Buttons (ActionButton/
    // MenuButton/Toggle) mit eingebauter Tooltip-Infra - HoverHandler +
    // ButtonTooltip daher hier direkt als zusätzliche Kinder drangehängt.
    Widgets.BatteryIndicator {
        id: batteryIndicator
        Layout.alignment: Qt.AlignVCenter
        // Gleicher 2px-Ausgleich wie ursprünglich in InfoView.qml: der
        // dünne (1.3px) Outline-Border ist anti-aliased und "verschwimmt"
        // dadurch sichtbar nach links über die 0-Kante hinaus.
        Layout.leftMargin: 2

        HoverHandler { id: batteryHover }
        ButtonTooltip {
            target: batteryIndicator
            text: root.batteryTooltip
            hovered: batteryHover.hovered
        }
    }

    LucideIcon {
        id: networkIcon
        Layout.alignment: Qt.AlignVCenter
        name: Services.Network.iconName
        size: 15
        color: Theme.colors.textMuted

        HoverHandler { id: networkHover }
        ButtonTooltip {
            target: networkIcon
            text: root.networkTooltip
            hovered: networkHover.hovered
        }
    }

    Item { Layout.fillWidth: true }

    ActionButton {
        Layout.alignment: Qt.AlignVCenter
        icon: "x"
        iconSize: 14
        diameter: 22
        tooltip: Localization.viewHeader.close
        onTapped: root.islandRoot.closeView()
    }
}
