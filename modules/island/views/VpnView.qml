import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../.."
import "../../../services" as Services

// Volle VPN-Ansicht: Reiter oben (OpenVPN aktiv, eduVPN strukturell schon
// da aber deaktiviert - siehe services/Vpn.qml Kopfkommentar), darunter
// die Details der gerade AUSGEWÄHLTEN Verbindung (Status, Verbinden/
// Trennen, Voller-Tunnel/Split-Tunnel-Schalter, Autostart-Schalter, bei
// aktiver Verbindung zusätzlich die IP/Latenz/Durchsatz-Statistik über
// services/NetworkStats.qml - dasselbe generische Interface-Backend, das
// WifiView schon nutzt). Darunter eine scrollbare Liste der ÜBRIGEN
// Verbindungen (alles außer der gerade ausgewählten) - antippen wählt eine
// andere Verbindung aus (wechselt NUR die Detailansicht, verbindet nicht
// automatisch, siehe activateNetwork-Pendant in WifiView.qml für den
// Kontrast: dort verbindet ein Tap sofort, hier nicht, weil bei VPN auch
// reine Profil-Einstellungen wie Autostart/Tunnel-Modus OHNE Verbindungs-
// aufbau änderbar sein sollen). Ein Hover-Aktionsbutton pro Zeile
// verbindet/trennt trotzdem mit einem Tap, wie bei WLAN/Bluetooth. Ganz
// unten eine Drop-Zone: eine .ovpn-Datei reinziehen importiert sie als
// neues NetworkManager-Profil (services/Vpn.qml/importFile()).
MorphItem {
    id: view

    name: "vpn"
    preferredWidth: 340
    preferredHeight: 520

    required property var islandRoot

    // Nur OpenVPN ist aktuell verdrahtet (services/Vpn.qml). Eigener
    // "currentConnections"-Name statt direkt Services.Vpn.openvpnConnections
    // überall zu schreiben - sobald eduVPN-Reiter mal antippbar wird,
    // reicht hier eine einzelne Umschaltung (activeTab-Property + Wahl
    // zwischen openvpnConnections/eduvpnConnections) statt jede Stelle
    // unten einzeln anzufassen.
    readonly property var currentConnections: Services.Vpn.openvpnConnections

    property string selectedId: ""
    readonly property var selectedConnection: view.currentConnections.find(c => c.id === view.selectedId) || null
    readonly property bool hasSelection: view.selectedConnection !== null
    // Skalare Kopien statt überall `view.selectedConnection.xxx` zu lesen -
    // ohne das müsste JEDE Bindung im (unsichtbaren, wenn nichts
    // ausgewählt ist) Detailblock unten einzeln gegen null absichern, das
    // wäre bei ~10 Bindungen unübersichtlich UND fehleranfällig (QML
    // wertet Bindings unabhängig von `visible` aus - ein direkter Zugriff
    // auf selectedConnection.name würde bei null sofort werfen, selbst
    // wenn der Block gerade unsichtbar ist).
    readonly property string selName: view.hasSelection ? view.selectedConnection.name : ""
    readonly property bool selActive: view.hasSelection ? view.selectedConnection.active : false
    readonly property bool selFullTunnel: view.hasSelection ? view.selectedConnection.fullTunnel : true
    readonly property bool selAutoConnect: view.hasSelection ? view.selectedConnection.autoConnect : false
    readonly property string selDevice: view.hasSelection ? view.selectedConnection.device : ""
    readonly property string selId: view.hasSelection ? view.selectedConnection.id : ""
    readonly property bool selPending: view.hasSelection && Services.Vpn.isPending(view.selId)

    // "Andere Verbindungen" = alles außer der gerade oben angezeigten -
    // exakt die Liste, die laut Anforderung unter den Details der
    // ausgewählten Verbindung stehen soll. Ein Tap darauf wechselt einfach
    // `selectedId`, wodurch dieselbe Verbindung aus dieser Liste
    // verschwindet und stattdessen oben auftaucht (und umgekehrt die
    // vorher oben stehende hier wieder erscheint).
    readonly property var otherConnections: view.currentConnections.filter(c => c.id !== view.selectedId)

    property string errorText: ""

    // Wählt eine sinnvolle Verbindung aus, falls gerade keine (mehr)
    // ausgewählt ist - bevorzugt eine AKTIVE (das ist es, was man beim
    // Öffnen typischerweise sehen will), sonst einfach die erste. Rührt
    // eine bereits gültige Auswahl NICHT an (früher Return oben) - wird
    // deshalb gefahrlos sowohl beim Öffnen als auch bei jeder Änderung der
    // Verbindungsliste aufgerufen (siehe onCurrentConnectionsChanged
    // unten), ohne die Auswahl des Nutzers zwischendrin wegzureißen.
    function ensureSelection() {
        if (view.hasSelection) return;
        if (view.currentConnections.length === 0) { view.selectedId = ""; return; }
        const activeOnes = view.currentConnections.filter(c => c.active);
        view.selectedId = activeOnes.length > 0 ? activeOnes[0].id : view.currentConnections[0].id;
    }

    onCurrentConnectionsChanged: if (view.active) view.ensureSelection()

    // NetworkStats ans tun-Interface der ausgewählten Verbindung koppeln -
    // nur solange die View offen UND die Auswahl tatsächlich aktiv ist
    // (siehe Kopfkommentar). setInterface()/setMeasuring() sind beide
    // idempotent (früher Return bei unverändertem Wert, siehe
    // services/NetworkStats.qml), ein mehrfacher Aufruf pro Polling-Tick
    // schadet also nicht.
    function syncStats() {
        if (view.active && view.selActive && view.selDevice.length > 0) {
            Services.NetworkStats.setInterface(view.selDevice);
            Services.NetworkStats.setMeasuring(true);
        } else {
            Services.NetworkStats.setMeasuring(false);
        }
    }
    onSelDeviceChanged: view.syncStats()
    onSelActiveChanged: view.syncStats()

    // Polling läuft nur, während die View offen ist - dasselbe Muster wie
    // Network.setWifiScanning()/Bluetooth.setDiscovering() (siehe
    // services/Vpn.qml).
    onActiveChanged: {
        Services.Vpn.setPolling(view.active)
        if (view.active) {
            view.ensureSelection()
            view.syncStats()
            list.forceActiveFocus()
        } else {
            Services.NetworkStats.setMeasuring(false)
            view.errorText = ""
            view.selectedId = ""
        }
    }

    Connections {
        target: Services.Vpn
        function onImportFailed(reason) { view.errorText = Localization.vpn.importFailedPrefix + reason }
        function onImportSucceeded(name) { view.errorText = "" }
        function onActionFailed(reason) { view.errorText = Localization.vpn.actionFailedPrefix + reason }
    }

    // Wandelt eine per Drag&Drop erhaltene "file://"-URL in einen lokalen
    // Pfad um - Gegenstück zu Network.qml, das umgekehrt "file://" + path
    // fürs QR-Code-Image zusammensetzt.
    function _localPath(url) {
        const s = url.toString();
        return s.startsWith("file://") ? decodeURIComponent(s.slice(7)) : s;
    }

    // Eine Verbindungs-Zeile in der unteren Liste - Icon + Name + Status,
    // Tap wählt aus (siehe Kopfkommentar für die Begründung, warum das
    // NICHT sofort verbindet), der Hover-Aktionsbutton verbindet/trennt
    // direkt. Gleiches Muster wie NetworkRow (WifiView.qml)/DeviceRow
    // (BluetoothView.qml).
    component ConnectionRow: ListCard {
        id: row
        required property var connection
        property bool current: false
        Layout.fillWidth: true
        selected: row.current || row.connection.id === view.selectedId
        spacing: 0

        readonly property bool pending: Services.Vpn.isPending(row.connection.id)

        LucideIcon {
            name: "shield-lock"
            size: 18
            color: row.connection.active ? Theme.colors.accent : Theme.colors.textMuted
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: row.connection.name
                color: row.connection.active ? Theme.colors.accent : Theme.colors.text
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size
                font.bold: row.connection.active
                elide: Text.ElideRight
            }
            Text {
                text: row.pending
                    ? (row.connection.active ? Localization.vpn.disconnecting : Localization.vpn.connecting)
                    : (row.connection.active ? Localization.vpn.connected : Localization.vpn.disconnected)
                color: Theme.colors.textMuted
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 3
            }
        }

        LucideIcon {
            visible: row.pending
            Layout.leftMargin: 8
            name: "loader-circle"
            size: 15
            color: Theme.colors.textMuted

            RotationAnimation on rotation {
                running: row.pending
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 900
            }
        }

        // Siehe WifiView.qml/NetworkRow für die ausführliche Begründung
        // des `shown`-Musters (ein einziger Code-Pfad statt zweier leicht
        // abweichender Zustände).
        ActionButton {
            id: rowAction
            available: !row.pending
            readonly property bool shown: rowAction.available && (row.hovered || rowAction.activeFocus)
            Layout.preferredWidth: rowAction.shown ? rowAction.diameter : 0
            Layout.leftMargin: rowAction.shown ? 8 : 0
            opacity: rowAction.shown ? 1 : 0
            icon: row.connection.active ? "log-out" : "plug-zap"
            iconSize: 13
            diameter: 24
            showBackground: false
            tooltip: row.connection.active ? Localization.vpn.disconnect : Localization.vpn.connect
            onTapped: row.connection.active ? Services.Vpn.disconnect(row.connection.id) : Services.Vpn.connect(row.connection.id)

            Behavior on Layout.preferredWidth { NumberAnimation { duration: Theme.animationDurations.short } }
            Behavior on Layout.leftMargin { NumberAnimation { duration: Theme.animationDurations.short } }
            Behavior on opacity { NumberAnimation { duration: Theme.animationDurations.short } }
        }

        TapHandler {
            onTapped: view.selectedId = row.connection.id
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Kein Akku-/Verbindungs-Status hier - siehe ViewHeader.qml/
        // AudioSourceView.qml für dieselbe Begründung.
        ViewHeader { islandRoot: view.islandRoot; showStatus: false }

        // --- Reiter: OpenVPN (aktiv) / eduVPN (strukturell vorbereitet,
        // aber deaktiviert - siehe Kopfkommentar services/Vpn.qml) ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MenuButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.preferredHeight: 30
                showLabel: true
                label: Localization.vpn.tabOpenvpn
                active: true
            }
            MenuButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.preferredHeight: 30
                showLabel: true
                label: Localization.vpn.tabEduvpn
                active: false
                available: false
                tooltip: Localization.vpn.tabEduvpnTooltip
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 20
            visible: view.currentConnections.length === 0
            text: Localization.vpn.noConnections
            horizontalAlignment: Text.AlignHCenter
            color: Theme.colors.textMuted
            font.family: Theme.font.family
            font.pixelSize: Theme.font.size - 2
        }

        // --- Details der ausgewählten Verbindung ---
        ColumnLayout {
            Layout.fillWidth: true
            visible: view.hasSelection
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                LucideIcon {
                    name: "shield-lock"
                    size: 18
                    color: view.selActive ? Theme.colors.accent : Theme.colors.textMuted
                }
                Text {
                    Layout.fillWidth: true
                    text: view.selName
                    color: view.selActive ? Theme.colors.accent : Theme.colors.text
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.size
                    font.bold: true
                    elide: Text.ElideRight
                }
                ActionButton {
                    icon: "trash-2"
                    iconSize: 12
                    diameter: 22
                    showBackground: false
                    tooltip: Localization.vpn.forgetTooltip
                    onTapped: Services.Vpn.forget(view.selId)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: view.selPending
                        ? (view.selActive ? Localization.vpn.disconnecting : Localization.vpn.connecting)
                        : (view.selActive ? Localization.vpn.connected : Localization.vpn.disconnected)
                    color: view.selActive ? Theme.colors.accent : Theme.colors.textMuted
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.size - 2
                }

                LucideIcon {
                    visible: view.selPending
                    name: "loader-circle"
                    size: 15
                    color: Theme.colors.textMuted

                    RotationAnimation on rotation {
                        running: view.selPending
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                    }
                }
                ActionButton {
                    visible: !view.selPending
                    icon: view.selActive ? "log-out" : "plug-zap"
                    iconSize: 13
                    diameter: 26
                    tooltip: view.selActive ? Localization.vpn.disconnect : Localization.vpn.connect
                    onTapped: view.selActive ? Services.Vpn.disconnect(view.selId) : Services.Vpn.connect(view.selId)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Toggle {
                    checked: view.selFullTunnel
                    tooltip: Localization.vpn.tunnelTooltip
                    onToggled: Services.Vpn.setFullTunnel(view.selId, !view.selFullTunnel)
                }
                Text {
                    text: view.selFullTunnel ? Localization.vpn.fullTunnelLabel : Localization.vpn.splitTunnelLabel
                    color: Theme.colors.text
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.size - 2
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Toggle {
                    checked: view.selAutoConnect
                    tooltip: Localization.vpn.autoStartTooltip
                    onToggled: Services.Vpn.setAutoStart(view.selId, !view.selAutoConnect)
                }
                Text {
                    text: Localization.vpn.autoStartLabel
                    color: Theme.colors.text
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.size - 2
                }
            }

            // --- Statistik-Kachel - nur bei tatsächlich aktiver
            // Verbindung (ohne laufendes Interface wären das nur "–"-
            // Platzhalter, siehe WifiView.qml für dasselbe Muster). ---
            GridLayout {
                Layout.fillWidth: true
                visible: view.selActive
                columns: 2
                columnSpacing: 16
                rowSpacing: 2

                StatRow {
                    Layout.columnSpan: 2
                    label: Localization.vpn.ipLabel
                    value: Services.NetworkStats.ipAddress.length > 0 ? Services.NetworkStats.ipAddress : "–"
                }
                StatRow {
                    label: Localization.vpn.latencyLabel
                    value: Services.NetworkStats.latencyMs >= 0 ? Math.round(Services.NetworkStats.latencyMs) + " ms" : "–"
                }
                StatRow {
                    label: Localization.vpn.packetLossLabel
                    value: Services.NetworkStats.pingsSent > 0 ? Math.round(Services.NetworkStats.packetLoss * 100) + "%" : "–"
                }
                StatRow {
                    label: Localization.vpn.receivingLabel
                    value: Services.NetworkStats.formatRate(Services.NetworkStats.rxRate)
                }
                StatRow {
                    label: Localization.vpn.sendingLabel
                    value: Services.NetworkStats.formatRate(Services.NetworkStats.txRate)
                }
                StatRow {
                    label: Localization.vpn.downloadedLabel
                    value: Services.NetworkStats.formatBytes(Services.NetworkStats.rxBytes)
                }
                StatRow {
                    label: Localization.vpn.uploadedLabel
                    value: Services.NetworkStats.formatBytes(Services.NetworkStats.txBytes)
                }
            }
        }

        Divider { visible: view.hasSelection && view.otherConnections.length > 0 }

        // --- Übrige Verbindungen ---
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: view.otherConnections
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 100
            // Siehe WifiView.qml für die ausführliche Begründung - ohne
            // das war die Liste per Tab nach dem ersten Verlassen nie
            // wieder erreichbar.
            activeFocusOnTab: true

            function activateCurrent() {
                const c = view.otherConnections[list.currentIndex]
                if (c) view.selectedId = c.id
            }
            Keys.onReturnPressed: list.activateCurrent()
            Keys.onEnterPressed: list.activateCurrent()

            delegate: Item {
                id: wrapper
                required property var modelData
                required property int index
                width: ListView.view.width
                implicitHeight: 44

                ConnectionRow {
                    anchors.fill: parent
                    connection: wrapper.modelData
                    current: list.currentIndex === wrapper.index
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: view.errorText.length > 0
            text: view.errorText
            wrapMode: Text.WordWrap
            color: Theme.colors.error
            font.family: Theme.font.family
            font.pixelSize: Theme.font.size - 3
        }

        // --- Drop-Zone: .ovpn-Datei reinziehen importiert sie als neues
        // NetworkManager-Profil (services/Vpn.qml/importFile()). ---
        Rectangle {
            id: dropZone
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            radius: 10
            color: "transparent"
            border.width: 1
            border.color: dropArea.containsDrag ? Theme.colors.accent : Theme.colors.borderSurface

            Behavior on border.color { ColorAnimation { duration: Theme.animationDurations.short } }

            RowLayout {
                anchors.centerIn: parent
                spacing: 8

                LucideIcon {
                    name: "upload"
                    size: 14
                    color: dropArea.containsDrag ? Theme.colors.accent : Theme.colors.textMuted
                }
                Text {
                    text: dropArea.containsDrag ? Localization.vpn.dropHintActive : Localization.vpn.dropHint
                    color: dropArea.containsDrag ? Theme.colors.accent : Theme.colors.textMuted
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.size - 3
                }
            }

            DropArea {
                id: dropArea
                anchors.fill: parent
                keys: ["text/uri-list"]
                onDropped: drop => {
                    const urls = drop.urls || [];
                    for (const u of urls) Services.Vpn.importFile(view._localPath(u));
                    drop.accepted = urls.length > 0;
                }
            }
        }
    }
}
