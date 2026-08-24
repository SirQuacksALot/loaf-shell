import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Networking
import ".."
import "../.."
import "../../.."
import "../../../services" as Services

// Volle WLAN-Ansicht: Funk-Toggle, verbundenes Netz oben (per Trennlinie
// abgesetzt), darunter scrollbare Liste der übrigen gefundenen Netze
// (Signalstärke, Sicherheit, bekannt), Verbinden (inkl. Passwort-Eingabe
// für gesicherte, noch nicht bekannte Netze), Trennen, Vergessen.
// Datenquelle ist services/Network.qml (Wrapper um Quickshells natives
// Quickshell.Networking-Modul, NetworkManager via D-Bus).
MorphItem {
    id: view

    name: "wifi"
    preferredWidth: 300
    preferredHeight: 360

    required property var islandRoot

    readonly property var connectedNetworks: Services.Network.wifiNetworks.filter(n => n.connected)
    readonly property var otherNetworks: Services.Network.wifiNetworks.filter(n => !n.connected)

    // Name des Netzes, dessen Passwort-Eingabe gerade aufgeklappt ist -
    // höchstens eins gleichzeitig, daher reicht ein einzelner String statt
    // eines Sets. Wird geleert, sobald verbunden/geschlossen/ein anderes
    // Netz angetippt wird.
    property string expandedNetwork: ""
    property string connectError: ""

    // Scannen läuft nur, während die View offen ist - kein Dauerfunk im
    // Hintergrund. Beim Öffnen zusätzlich alles zuklappen (falls die View
    // vorher mit offener Passwort-Eingabe verlassen wurde).
    onActiveChanged: {
        Services.Network.setWifiScanning(view.active)
        if (view.active) {
            // Fokus auf die Liste (nicht nur irgendein Item) - erteilt dem
            // Fenster überhaupt erst Tastaturfokus (WlrKeyboardFocus.
            // OnDemand, siehe IslandRoot.qml) UND aktiviert gleichzeitig
            // Pfeiltasten-Navigation innerhalb der Liste (ListView-
            // Standardverhalten). Tab bubbelt von dort trotzdem weiter zu
            // MorphContainer.qml, das erreicht auch die Header-Buttons.
            list.forceActiveFocus()
        } else {
            view.expandedNetwork = ""
            view.connectError = ""
        }
    }

    // Von NetworkRow.TapHandler UND ListView.Keys.onReturnPressed genutzt,
    // damit die Verbinden/Passwort-aufklappen-Logik nur an einer Stelle steht.
    function activateNetwork(network) {
        if (!network || network.connected) return
        view.connectError = ""
        if (network.known || network.security === WifiSecurityType.Open) {
            view.expandedNetwork = ""
            network.connect()
        } else {
            view.expandedNetwork = view.expandedNetwork === network.name ? "" : network.name
        }
    }

    // Eine Netz-Zeile, größer als vorher (mehr Zeilenhöhe/Icon-Größe) -
    // sowohl fürs verbundene Netz oben als auch die Liste darunter genutzt,
    // damit Verbinden/Trennen/Passwort-Logik nicht doppelt existiert. Kein
    // Häkchen mehr für "verbunden" - das übernimmt jetzt allein die
    // Trennlinie zwischen verbundenem Netz und dem Rest.
    component NetworkRow: ColumnLayout {
        id: row
        required property var network
        // Per Pfeiltasten ausgewählt (nur innerhalb der scrollbaren Liste
        // relevant, siehe delegate unten) - hebt die Karte über
        // ListCard.selected farblich hervor (Hintergrund), siehe dort.
        property bool current: false
        Layout.fillWidth: true
        spacing: 8

        readonly property bool expanded: view.expandedNetwork === row.network.name
        readonly property bool secured: row.network.security !== WifiSecurityType.Open

        ListCard {
            id: card
            Layout.fillWidth: true
            // Tastatur-Auswahl hebt sich jetzt über den Hintergrund ab
            // (wie Hover), nicht mehr über die Textfarbe - die zeigt
            // stattdessen, ob das Netz tatsächlich verbunden ist.
            selected: row.current

            LucideIcon {
                // WifiNetwork.signalStrength ist ein Bruch (0.0-1.0), kein
                // Prozentwert - siehe services/Network.qml.
                name: row.network.signalStrength >= 0.67 ? "wifi-high" : (row.network.signalStrength >= 0.34 ? "wifi-low" : "wifi-zero")
                size: 18
                color: row.network.connected ? Theme.colors.accent : Theme.colors.textMuted
            }

            Text {
                Layout.fillWidth: true
                text: row.network.name
                color: row.network.connected ? Theme.colors.accent : Theme.colors.text
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size
                font.bold: row.network.connected
                elide: Text.ElideRight

                Behavior on color { ColorAnimation { duration: Theme.animationDurations.short } }
            }

            LucideIcon {
                visible: row.secured
                name: "lock-keyhole"
                size: 14
                color: Theme.colors.textMuted
            }

            // Trennen (verbunden) bzw. Vergessen (bekannt, nicht
            // verbunden). Optisch nur bei Hover ODER Tastaturfokus sichtbar
            // (Ruhezustand der Liste bleibt aufgeräumt), aber IMMER Teil
            // der Tab-Kette, solange die Aktion überhaupt gilt - über
            // opacity statt visible, weil ein `visible:false`-Item nie per
            // Tab fokussierbar wäre (nextItemInFocusChain überspringt
            // unsichtbare Items) und Tastaturnutzer die Aktion sonst nie
            // erreichen könnten.
            ActionButton {
                id: rowAction
                available: row.network.connected || row.network.known
                opacity: rowAction.available && (card.hovered || rowAction.activeFocus) ? 1 : 0
                icon: row.network.connected ? "log-out" : "trash-2"
                iconSize: 13
                diameter: 24
                showBackground: false
                tooltip: row.network.connected ? Localization.wifi.disconnect : Localization.wifi.forget
                onTapped: row.network.connected ? row.network.disconnect() : row.network.forget()
            }

            TapHandler {
                onTapped: view.activateNetwork(row.network)
            }
        }

        // --- Passwort-Eingabe für gesicherte, unbekannte Netze ---
        RowLayout {
            Layout.fillWidth: true
            visible: row.expanded
            spacing: 6

            TextField {
                id: pwField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: Localization.wifi.passwordPlaceholder
                color: Theme.colors.text
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 2
                background: Rectangle {
                    radius: 8
                    color: Theme.colors.surface
                    border.width: 1
                    border.color: Theme.colors.borderSurface
                }
                onAccepted: row.network.connectWithPsk(text)
                Component.onCompleted: if (row.expanded) forceActiveFocus()
            }
            ActionButton {
                icon: "check"
                iconSize: 12
                diameter: 26
                tooltip: Localization.wifi.connect
                onTapped: row.network.connectWithPsk(pwField.text)
            }
        }
        Text {
            Layout.fillWidth: true
            visible: row.expanded && view.connectError.length > 0
            text: view.connectError
            color: Theme.colors.error
            font.family: Theme.font.family
            font.pixelSize: Theme.font.size - 3
        }

        Connections {
            target: row.network
            function onConnectionFailed(reason) {
                if (!row.expanded) return
                view.connectError = ConnectionFailReason.toString(reason)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Toggle {
                checked: Services.Network.wifiEnabled
                tooltip: checked ? Localization.wifi.turnOff : Localization.wifi.turnOn
                onToggled: Services.Network.toggleWifi()
            }

            // Nur die kurze Switch-Beschreibung - kein Verbindungsstatus
            // mehr daneben, das verbundene Netz steht ja bereits eigens
            // (per Trennlinie abgesetzt) weiter unten in der Liste.
            Text {
                text: Localization.wifi.sectionLabel
                color: Theme.colors.textMuted
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 2
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 20
            visible: Services.Network.wifiEnabled && Services.Network.wifiNetworks.length === 0
            text: Localization.wifi.searchingNetworks
            horizontalAlignment: Text.AlignHCenter
            color: Theme.colors.textMuted
            font.family: Theme.font.family
            font.pixelSize: Theme.font.size - 2
        }

        // --- Verbundenes Netz, oben, nicht Teil der scrollbaren Liste ---
        ColumnLayout {
            Layout.fillWidth: true
            visible: view.connectedNetworks.length > 0

            Repeater {
                model: view.connectedNetworks
                delegate: NetworkRow {
                    required property var modelData
                    network: modelData
                }
            }
        }

        Divider { visible: view.connectedNetworks.length > 0 }

        // --- Restliche gefundene Netze ---
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Services.Network.wifiEnabled
            clip: true
            spacing: 4
            model: view.otherNetworks
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 100

            Keys.onReturnPressed: view.activateNetwork(view.otherNetworks[list.currentIndex])
            Keys.onEnterPressed: view.activateNetwork(view.otherNetworks[list.currentIndex])

            // Wrapper-Item statt NetworkRow direkt als Delegate - eine
            // Layout.fillWidth-lose Rechteck-Ecke fürs Tastatur-Highlight
            // ließe sich NICHT einfach als weiteres Kind in NetworkRow
            // (ein ColumnLayout) hängen: Qt Quick Layouts unterstützen
            // keine `anchors` auf ihren Kindern, ein zusätzliches Item
            // dort würde stattdessen einfach als weitere Zeile mit
            // eingeordnet statt zu überlagern.
            delegate: Item {
                id: wrapper
                required property var modelData
                required property int index
                width: ListView.view.width
                implicitHeight: content.implicitHeight

                NetworkRow {
                    id: content
                    anchors.fill: parent
                    network: wrapper.modelData
                    current: list.currentIndex === wrapper.index
                }
            }
        }
    }
}
