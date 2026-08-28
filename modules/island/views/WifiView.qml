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
    preferredWidth: 340
    // War 360 - +90 für die Statistik-Kachel (IP/Latenz/Paketverlust/
    // Durchsatz) über der Liste, siehe unten.
    preferredHeight: 450

    required property var islandRoot

    readonly property var connectedNetworks: Services.Network.wifiNetworks.filter(n => n.connected)
    // "Bekannt" = gespeichertes Profil, aber gerade nicht verbunden - vs.
    // gefundene, noch nie verbundene Netze. Zwei getrennte Gruppen unten
    // in der Liste, analog zu paired/discovered in BluetoothView.qml.
    readonly property var knownNetworks: Services.Network.wifiNetworks.filter(n => !n.connected && n.known)
    readonly property var foundNetworks: Services.Network.wifiNetworks.filter(n => !n.connected && !n.known)

    // Gemischtes Modell für die EINE scrollbare Liste, mit echten
    // Abschnitts-Headern statt einer bloßen Trennlinie - gleiches Muster
    // wie otherDevicesModel in BluetoothView.qml (dortiger Kommentar für
    // die ausführliche Begründung). Jeder Header nur, wenn seine Gruppe
    // tatsächlich nicht leer ist.
    readonly property var otherNetworksModel: {
        const items = [];
        if (view.knownNetworks.length > 0) items.push({ kind: "header", label: Localization.wifi.knownNetworksLabel, network: null });
        for (const n of view.knownNetworks) items.push({ kind: "network", network: n });
        if (view.foundNetworks.length > 0) items.push({ kind: "header", label: Localization.wifi.otherNetworksLabel, network: null });
        for (const n of view.foundNetworks) items.push({ kind: "network", network: n });
        return items;
    }

    // Name des Netzes, dessen Passwort-Eingabe gerade aufgeklappt ist -
    // höchstens eins gleichzeitig, daher reicht ein einzelner String statt
    // eines Sets. Wird geleert, sobald verbunden/geschlossen/ein anderes
    // Netz angetippt wird.
    property string expandedNetwork: ""
    property string connectError: ""

    // --- QR-Code-Anzeige (SSID+Passwort teilen, siehe QR-Button unten) ---
    property bool showQr: false
    property string qrPath: ""
    property bool qrError: false

    Connections {
        target: Services.Network
        function onQrReady(path) {
            // Gleicher Reset-Trick wie beim Clipboard-Thumbnail
            // (ClipboardView.qml) - Image lädt bei identischem
            // source-String sonst nicht neu, falls schon mal ein QR
            // unter demselben Pfad angezeigt wurde.
            view.qrPath = "";
            view.qrPath = "file://" + path;
        }
        function onQrFailed() {
            view.qrError = true;
        }
    }

    // Scannen läuft nur, während die View offen ist - kein Dauerfunk im
    // Hintergrund. Beim Öffnen zusätzlich alles zuklappen (falls die View
    // vorher mit offener Passwort-Eingabe verlassen wurde).
    onActiveChanged: {
        Services.Network.setWifiScanning(view.active)
        // NetworkStats kennt "sein" Interface nicht selbst (siehe
        // dortiger Kopfkommentar) - hier verdrahtet, weil hier bekannt
        // ist, welches Interface gerade das WLAN-Device ist. Messen nur,
        // solange die View offen ist, exakt wie beim Scanning oben (kein
        // Dauer-Ping im Hintergrund).
        Services.NetworkStats.setInterface(Services.Network.wifiDevice ? Services.Network.wifiDevice.name : "")
        Services.NetworkStats.setMeasuring(view.active)
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
            view.showQr = false
            view.qrPath = ""
            view.qrError = false
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
            // 0 statt der ListCard-Standard-8 - der Abstand kommt jetzt
            // von jedem Kind einzeln per Layout.leftMargin (siehe
            // ActionButton unten für den Grund: negative Margins, um die
            // Standard-spacing wegzukürzen, werden von Qt Quick Layouts
            // stillschweigend auf 0 geklemmt, das lässt sich nur so
            // sauber lösen, nicht durch bloßes Verrechnen).
            spacing: 0

            LucideIcon {
                // WifiNetwork.signalStrength ist ein Bruch (0.0-1.0), kein
                // Prozentwert - siehe services/Network.qml.
                name: row.network.signalStrength >= 0.67 ? "wifi-high" : (row.network.signalStrength >= 0.34 ? "wifi-low" : "wifi-zero")
                size: 18
                color: row.network.connected ? Theme.colors.accent : Theme.colors.textMuted
            }

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 8
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
                Layout.leftMargin: 8
                name: "lock-keyhole"
                size: 14
                color: Theme.colors.textMuted
            }

            // Trennen (verbunden) bzw. Vergessen (bekannt, nicht
            // verbunden). EIN Code-Pfad für alle Zeilen (available/
            // unbekannt) statt zwei getrennter - `shown` verlangt
            // available MIT, der Button bleibt für nie verfügbare Zeilen
            // (unbekannte Netze) also strukturell exakt derselbe wie im
            // nicht gehoverten Ruhezustand einer verfügbaren Zeile (0
            // Breite, 0 Zusatzabstand, unsichtbar) - kein zweiter, evtl.
            // leicht abweichender Zustand mehr möglich. ActionButton.qml
            // selbst blockt onTapped ohnehin schon über sein eigenes
            // `available` (TapHandler.enabled), von hier also ungefährlich.
            ActionButton {
                id: rowAction
                available: row.network.connected || row.network.known
                readonly property bool shown: rowAction.available && (card.hovered || rowAction.activeFocus)
                Layout.preferredWidth: rowAction.shown ? rowAction.diameter : 0
                // Nur bei Hover/Fokus die 8px-Lücke davor - card.spacing
                // ist jetzt 0 (siehe oben), jedes Kind trägt seinen
                // eigenen Abstand.
                Layout.leftMargin: rowAction.shown ? 8 : 0
                opacity: rowAction.shown ? 1 : 0
                icon: row.network.connected ? "log-out" : "trash-2"
                iconSize: 13
                diameter: 24
                showBackground: false
                tooltip: row.network.connected ? Localization.wifi.disconnect : Localization.wifi.forget
                onTapped: row.network.connected ? row.network.disconnect() : row.network.forget()

                Behavior on Layout.preferredWidth { NumberAnimation { duration: Theme.animationDurations.short } }
                Behavior on Layout.leftMargin { NumberAnimation { duration: Theme.animationDurations.short } }
                Behavior on opacity { NumberAnimation { duration: Theme.animationDurations.short } }
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

            Item { Layout.fillWidth: true }

            // QR-Button oben rechts - gleiche Position/Optik wie der
            // Scan-Button in BluetoothView.qml. Teilt SSID+Passwort des
            // verbundenen Netzes als WIFI:-QR-Code (siehe
            // services/Network.qml/generateWifiQr()), nur verfügbar,
            // solange tatsächlich verbunden. Toggle-Verhalten: erneutes
            // Antippen schließt die QR-Ansicht wieder.
            ActionButton {
                icon: "qr-code"
                iconSize: 13
                diameter: 22
                available: view.connectedNetworks.length > 0
                tooltip: Localization.wifi.qrTooltip
                onTapped: {
                    if (view.showQr) {
                        view.showQr = false;
                    } else {
                        view.qrPath = "";
                        view.qrError = false;
                        Services.Network.generateWifiQr(view.connectedNetworks[0]);
                        view.showQr = true;
                    }
                }
            }
        }

        // --- QR-Code-Ansicht - ersetzt die Netzliste komplett, solange
        // offen. Eigener Block statt eines Overlays, damit sich Höhe/
        // Fokuskette derselben MorphItem-Choreographie unterordnen wie
        // der Rest der View. ---
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: view.showQr
            spacing: 10

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 30
                visible: !view.qrError && view.qrPath.length === 0
                text: Localization.wifi.searchingNetworks
                horizontalAlignment: Text.AlignHCenter
                color: Theme.colors.textMuted
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 2
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: 30
                visible: view.qrError
                text: Localization.wifi.qrFailed
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Theme.colors.error
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 2
            }

            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
                visible: !view.qrError && view.qrPath.length > 0
                source: view.qrPath
                sourceSize.width: 220
                sourceSize.height: 220
                // Kein Glätten - ein interpolierter QR-Code verliert die
                // scharfen Modul-Kanten, die Scanner zum Erkennen brauchen.
                smooth: false
            }

            Text {
                Layout.fillWidth: true
                visible: !view.qrError && view.qrPath.length > 0
                text: Localization.wifi.qrHint
                horizontalAlignment: Text.AlignHCenter
                color: Theme.colors.textMuted
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 3
            }

            Item { Layout.fillHeight: true }
        }

        // --- Bisheriger Inhalt (verbundenes Netz, Statistik, Netzliste) -
        // komplett ausgeblendet, solange die QR-Ansicht offen ist. ---
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !view.showQr
            spacing: 14

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

            // --- Statistik-Kachel: IP/Latenz/Paketverlust/Durchsatz ---
            // Nur sichtbar, solange tatsächlich verbunden - ohne IP-Adresse/
            // laufendes Interface wären das nur lauter "–"-Platzhalter.
            // services/NetworkStats.qml liefert die Werte, verdrahtet in
            // onActiveChanged oben.
            GridLayout {
                Layout.fillWidth: true
                visible: view.connectedNetworks.length > 0
                columns: 2
                columnSpacing: 16
                rowSpacing: 2

                component StatRow: RowLayout {
                    id: statRow
                    required property string label
                    required property string value
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: statRow.label
                        color: Theme.colors.textMuted
                        font.family: Theme.font.family
                        font.pixelSize: Theme.font.size - 3
                    }
                    Text {
                        text: statRow.value
                        color: Theme.colors.text
                        font.family: Theme.font.family
                        font.pixelSize: Theme.font.size - 3
                    }
                }

                StatRow {
                    Layout.columnSpan: 2
                    label: Localization.wifi.ipLabel
                    value: Services.NetworkStats.ipAddress.length > 0 ? Services.NetworkStats.ipAddress : "–"
                }
                StatRow {
                    label: Localization.wifi.latencyLabel
                    value: Services.NetworkStats.latencyMs >= 0 ? Math.round(Services.NetworkStats.latencyMs) + " ms" : "–"
                }
                StatRow {
                    label: Localization.wifi.packetLossLabel
                    value: Services.NetworkStats.pingsSent > 0 ? Math.round(Services.NetworkStats.packetLoss * 100) + "%" : "–"
                }
                StatRow {
                    label: Localization.wifi.receivingLabel
                    value: Services.NetworkStats.formatRate(Services.NetworkStats.rxRate)
                }
                StatRow {
                    label: Localization.wifi.sendingLabel
                    value: Services.NetworkStats.formatRate(Services.NetworkStats.txRate)
                }
                StatRow {
                    label: Localization.wifi.downloadedLabel
                    value: Services.NetworkStats.formatBytes(Services.NetworkStats.rxBytes)
                }
                StatRow {
                    label: Localization.wifi.uploadedLabel
                    value: Services.NetworkStats.formatBytes(Services.NetworkStats.txBytes)
                }
            }

            Divider { visible: view.connectedNetworks.length > 0 }

            // --- Restliche Netze (bekannt + gefunden), Header pro Gruppe
            // steckt schon im Modell (otherNetworksModel oben). ---
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: Services.Network.wifiEnabled
                clip: true
                spacing: 4
                model: view.otherNetworksModel
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 100
                // Ohne das: MorphContainer.qmls zentraler Tab-Handler
                // wandert nur durch Items mit activeFocusOnTab:true
                // (nextItemInFocusChain() traversiert genau die).
                // list.forceActiveFocus() beim Öffnen der View gibt der
                // Liste zwar EINMAL Fokus, aber sobald man per Tab zu
                // einem anderen Control weiterspringt (z.B. Toggle/QR-
                // Button oben), war die Liste selbst nie Teil der
                // Tab-Kette und dadurch per Tab nie wieder erreichbar -
                // besonders bei Zeilen ohne eigenen Action-Button
                // (unbekannte Netze) blieb man dann komplett ausgesperrt.
                activeFocusOnTab: true

                function activateCurrent() {
                    const item = view.otherNetworksModel[list.currentIndex]
                    if (item && item.kind === "network") view.activateNetwork(item.network)
                }
                Keys.onReturnPressed: list.activateCurrent()
                Keys.onEnterPressed: list.activateCurrent()

                // Wrapper-Item statt NetworkRow direkt als Delegate - eine
                // Layout.fillWidth-lose Rechteck-Ecke fürs Tastatur-Highlight
                // ließe sich NICHT einfach als weiteres Kind in NetworkRow
                // (ein ColumnLayout) hängen: Qt Quick Layouts unterstützen
                // keine `anchors` auf ihren Kindern, ein zusätzliches Item
                // dort würde stattdessen einfach als weitere Zeile mit
                // eingeordnet statt zu überlagern. Zusätzlich hier ein Loader
                // statt direkt NetworkRow, damit Header-Einträge (network:
                // null) NIE eine NetworkRow-Instanz erzeugen - deren
                // Bindings lesen ständig row.network.*, das würde bei null
                // sofort werfen (gleiches Muster wie BluetoothView.qml).
                delegate: Item {
                    id: wrapper
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    // .implicitHeight statt .height, UND der Loader
                    // unten bekommt NUR width (kein anchors.fill/height)
                    // - beides zusammen wichtig: NetworkRow ist (anders
                    // als BluetoothViews DeviceRow, ein ListCard mit
                    // fixen 44px) ein ColumnLayout mit VARIABLER Höhe
                    // (Passwort-Feld klappt auf). Ein Loader MIT
                    // gebundener height zwingt seinem Kind diese Höhe
                    // AUF (überschreibt dessen eigene implicitHeight-
                    // Berechnung) - genau das erzeugt hier einen
                    // Zirkelbezug (wrapper.implicitHeight <- rowLoader.
                    // item.height <- rowLoader.height <- wrapper.height
                    // <- wrapper.implicitHeight), der bei DeviceRows
                    // KONSTANTER Höhe zufällig aufgeht, bei NetworkRows
                    // variabler Höhe aber zu einem eingefrorenen Fantasie-
                    // wert führt - live beobachtet als überlappende
                    // Listenzeilen. Ohne height-Bindung auf dem Loader
                    // bestimmt NetworkRow seine Höhe ganz normal selbst.
                    implicitHeight: rowLoader.item ? rowLoader.item.implicitHeight : 24

                    Loader {
                        id: rowLoader
                        width: parent.width
                        sourceComponent: wrapper.modelData.kind === "header" ? headerComponent : networkComponent
                    }

                    Component {
                        id: headerComponent
                        // Item-Wrapper statt Text direkt - Text.implicitHeight
                        // ist read-only (aus den Font-Metriken abgeleitet),
                        // ein Item hat dagegen eine ganz normale, frei
                        // setzbare implicitHeight. Wrapper.implicitHeight
                        // oben liest genau die.
                        Item {
                            width: rowLoader.width
                            implicitHeight: 24

                            Text {
                                anchors.bottom: parent.bottom
                                text: wrapper.modelData.label
                                color: Theme.colors.textMuted
                                font.family: Theme.font.family
                                font.pixelSize: Theme.font.size - 2
                            }
                        }
                    }

                    Component {
                        id: networkComponent
                        NetworkRow {
                            network: wrapper.modelData.network
                            current: list.currentIndex === wrapper.index
                        }
                    }
                }
            }
        }
    }
}
