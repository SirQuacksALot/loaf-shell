import QtQuick
import QtQuick.Layouts
import "../.."

// Eine Label/Wert-Zeile für Verbindungsstatistiken (IP/Latenz/
// Paketverlust/Durchsatz) - ursprünglich eine Inline-Component nur in
// WifiView.qml, jetzt auch von VpnView.qml gebraucht (services/
// NetworkStats.qml ist bereits generisch über setInterface() für JEDES
// Interface nutzbar, nicht nur WLAN) - deshalb hierher gezogen, analog zu
// Divider.qml/ListCard.qml (siehe dortige Kommentare für dasselbe Muster:
// "war ursprünglich nur an einer Stelle, jetzt an zwei -> hierher gezogen").
RowLayout {
    id: root
    required property string label
    required property string value
    Layout.fillWidth: true
    spacing: 6

    Text {
        Layout.fillWidth: true
        text: root.label
        color: Theme.colors.textMuted
        font.family: Theme.font.family
        font.pixelSize: Theme.font.size - 3
    }
    Text {
        text: root.value
        color: Theme.colors.text
        font.family: Theme.font.family
        font.pixelSize: Theme.font.size - 3
    }
}
