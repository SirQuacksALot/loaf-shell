import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import ".."
import "../.."
import "../../.."
import "../../../services" as Services

// Volle Bluetooth-Ansicht: An/Aus-Toggle, Scan-Button (kein Dauer-Toggle,
// löst einen einmaligen 20s-Scan aus, kein Auto-Start beim Öffnen),
// verbundene Geräte oben (per Trennlinie abgesetzt), darunter EINE
// scrollbare Liste, intern nochmal per Trennlinie unterteilt: bekannte
// (gekoppelte) Geräte zuerst, dann neu gefundene. Koppeln/Verbinden/
// Trennen/Vergessen. Datenquelle ist services/Bluetooth.qml (Wrapper um
// Quickshells natives Quickshell.Bluetooth-Modul, BlueZ via D-Bus).
MorphItem {
    id: view

    name: "bluetooth"
    preferredWidth: 300
    preferredHeight: 360

    required property var islandRoot

    readonly property var connectedDevices: Services.Bluetooth.devices.filter(d => d.connected)
    // "Bekannt" = gekoppelt, aber gerade nicht verbunden - vs. neu beim
    // Scannen gefundene, noch nie gekoppelte Geräte. Zwei getrennte
    // Gruppen unterhalb der verbundenen Geräte, wie bei WifiView
    // verbunden/unverbunden, nur eine Ebene tiefer.
    readonly property var pairedDevices: Services.Bluetooth.devices.filter(d => !d.connected && d.paired)
    readonly property var discoveredDevices: Services.Bluetooth.devices.filter(d => !d.connected && !d.paired)

    // Gemischtes Modell für die EINE scrollbare Liste: bekannte Geräte,
    // optional eine Trennlinie, dann neu gefundene. Zwei separate
    // ListViews hätten sich nicht gemeinsam scrollen lassen - ein
    // ListView kennt aber auch keine "Trennlinie zwischen zwei
    // Abschnitten" von sich aus, daher hier ein Marker-Eintrag
    // (`divider: true`) statt eines echten Geräts, den der Delegate
    // unten per Loader anders rendert.
    readonly property var otherDevicesModel: {
        const items = [];
        for (const d of view.pairedDevices) items.push({ divider: false, device: d });
        if (view.pairedDevices.length > 0 && view.discoveredDevices.length > 0) {
            items.push({ divider: true, device: null });
        }
        for (const d of view.discoveredDevices) items.push({ divider: false, device: d });
        return items;
    }

    // Discovery läuft NICHT automatisch beim Öffnen - der Scan-Button
    // stößt einen zeitlich begrenzten Scan an (siehe scanTimer unten),
    // nicht "an, sobald die View offen ist". Nur beim Verlassen wird sie
    // sicherheitshalber ausgeschaltet (kein Dauerscan im Hintergrund,
    // falls man mittendrin rausgeht). Fokus auf die Liste (siehe
    // WifiView.qml für die ausführliche Begründung) erteilt dem Fenster
    // überhaupt erst Tastaturfokus UND aktiviert Pfeiltasten-Navigation.
    onActiveChanged: {
        if (!view.active) {
            Services.Bluetooth.setDiscovering(false)
            scanTimer.stop()
        }
        if (view.active) list.forceActiveFocus()
    }

    // Auf Root-Ebene statt tief verschachtelt in der RowLayout unten (wo
    // der Scan-Button sitzt) - onActiveChanged oben feuert bei Bedarf
    // schon, bevor tiefer verschachtelte Objekte fertig konstruiert sind,
    // ein Zugriff auf scanTimer von dort wäre dann ein ReferenceError.
    // Gleiches Muster wie hideTimer/notifyTimer in IslandRoot.qml.
    Timer {
        id: scanTimer
        interval: 20000
        onTriggered: Services.Bluetooth.setDiscovering(false)
    }

    function activateDevice(device) {
        if (!device || device.connected) return
        if (device.paired) device.connect()
        else device.pair()
    }

    // Eine Geräte-Zeile, größer als vorher (mehr Zeilenhöhe/Icon-Größe) -
    // sowohl für die verbundenen Geräte oben als auch die Liste darunter
    // genutzt. Kein Häkchen mehr für "verbunden" - das übernimmt jetzt
    // allein die Trennlinie zwischen verbundenen Geräten und dem Rest.
    component DeviceRow: ListCard {
        id: row
        required property var device
        // Per Pfeiltasten ausgewählt (siehe delegate unten) - hebt die
        // Karte über ListCard.selected farblich hervor (Hintergrund),
        // siehe dort. Textfarbe zeigt stattdessen, ob das Gerät
        // tatsächlich verbunden ist (wie bei WifiView.qml).
        property bool current: false
        Layout.fillWidth: true
        selected: row.current

        readonly property bool busy: row.device.pairing || row.device.state === BluetoothDeviceState.Connecting || row.device.state === BluetoothDeviceState.Disconnecting

        LucideIcon {
            name: Services.Bluetooth.iconFor(row.device)
            size: 18
            color: row.device.connected ? Theme.colors.accent : Theme.colors.textMuted
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: row.device.name
                color: row.device.connected ? Theme.colors.accent : Theme.colors.text
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size
                font.bold: row.device.connected
                elide: Text.ElideRight

                Behavior on color { ColorAnimation { duration: Theme.animationDurations.short } }
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: {
                    if (row.busy) return row.device.pairing ? Localization.bluetooth.pairing : Localization.bluetooth.connecting
                    if (row.device.connected && row.device.batteryAvailable) return Math.round(row.device.battery * 100) + Localization.common.percent
                    if (row.device.connected) return Localization.bluetooth.connected
                    if (row.device.paired) return Localization.bluetooth.paired
                    return ""
                }
                color: Theme.colors.textMuted
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 3
            }
        }

        LucideIcon {
            visible: row.busy
            name: "loader-circle"
            size: 15
            color: Theme.colors.textMuted

            RotationAnimation on rotation {
                running: row.busy
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 900
            }
        }

        // Trennen (verbunden) bzw. Vergessen (gekoppelt, nicht
        // verbunden). Optisch nur bei Hover ODER Tastaturfokus sichtbar,
        // aber IMMER Teil der Tab-Kette, solange die Aktion gilt - siehe
        // WifiView.qml für die ausführliche Begründung (opacity statt
        // visible, sonst nie per Tab erreichbar).
        ActionButton {
            id: rowAction
            available: !row.busy && (row.device.connected || row.device.paired)
            opacity: rowAction.available && (row.hovered || rowAction.activeFocus) ? 1 : 0
            icon: row.device.connected ? "log-out" : "trash-2"
            iconSize: 13
            diameter: 24
            showBackground: false
            tooltip: row.device.connected ? Localization.bluetooth.disconnect : Localization.bluetooth.forget
            onTapped: row.device.connected ? row.device.disconnect() : row.device.forget()
        }

        TapHandler {
            enabled: !row.busy
            onTapped: view.activateDevice(row.device)
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
                checked: Services.Bluetooth.enabled
                available: Services.Bluetooth.available
                tooltip: checked ? Localization.bluetooth.turnOff : Localization.bluetooth.turnOn
                onToggled: Services.Bluetooth.toggle()
            }

            // Nur die kurze Switch-Beschreibung - kein Verbindungsstatus/
            // Geräteliste mehr daneben (siehe WifiView.qml für dieselbe
            // Umstellung), die verbundenen Geräte stehen ja bereits eigens
            // weiter unten in der Liste.
            Text {
                text: Localization.bluetooth.sectionLabel
                color: Theme.colors.textMuted
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 2
            }

            Item { Layout.fillWidth: true }

            // Kein Dauer-Toggle mehr, sondern ein echter Scan-Button (mit
            // Hintergrund-Kachel wie der Schließen-Button anderswo, statt
            // nur bei laufender Suche eine einzublenden): ein Tap startet
            // einen zeitlich begrenzten Scan (20s), der sich selbst wieder
            // ausschaltet - kein manuelles "wieder ausschalten" nötig.
            // Ob gerade gesucht wird, steht im Tooltip.
            ActionButton {
                icon: "bluetooth-searching"
                iconSize: 13
                diameter: 22
                available: Services.Bluetooth.enabled
                tooltip: Services.Bluetooth.discovering ? Localization.bluetooth.discovering : Localization.bluetooth.discoverTooltip
                onTapped: {
                    Services.Bluetooth.setDiscovering(true)
                    scanTimer.restart()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 20
            visible: Services.Bluetooth.enabled && Services.Bluetooth.devices.length === 0
            text: Services.Bluetooth.discovering ? Localization.bluetooth.discoveringEmpty : Localization.bluetooth.noDevicesFound
            horizontalAlignment: Text.AlignHCenter
            color: Theme.colors.textMuted
            font.family: Theme.font.family
            font.pixelSize: Theme.font.size - 2
        }

        // --- Verbundene Geräte, oben, nicht Teil der scrollbaren Liste ---
        ColumnLayout {
            Layout.fillWidth: true
            visible: view.connectedDevices.length > 0

            Repeater {
                model: view.connectedDevices
                delegate: DeviceRow {
                    required property var modelData
                    device: modelData
                }
            }
        }

        Divider { visible: view.connectedDevices.length > 0 }

        // --- Restliche Geräte (gekoppelt + gefunden) ---
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Services.Bluetooth.enabled
            clip: true
            spacing: 4
            model: view.otherDevicesModel
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 100

            function activateCurrent() {
                const item = view.otherDevicesModel[list.currentIndex]
                if (item && !item.divider) view.activateDevice(item.device)
            }
            Keys.onReturnPressed: list.activateCurrent()
            Keys.onEnterPressed: list.activateCurrent()

            // Wrapper-Item statt DeviceRow (ein RowLayout) direkt als
            // Delegate - siehe WifiView.qml für die Begründung (Qt Quick
            // Layouts unterstützen keine `anchors` auf ihren Kindern).
            // Zusätzlich hier ein Loader statt direkt DeviceRow, damit
            // Trennlinien-Einträge (device: null) NIE eine DeviceRow-
            // Instanz erzeugen - deren Bindings lesen ständig row.device.*,
            // das würde bei null sofort werfen.
            delegate: Item {
                id: wrapper
                required property var modelData
                required property int index
                width: ListView.view.width
                implicitHeight: rowLoader.item ? rowLoader.item.height : 44

                Loader {
                    id: rowLoader
                    anchors.fill: parent
                    sourceComponent: wrapper.modelData.divider ? dividerComponent : deviceComponent
                }

                Component {
                    id: dividerComponent
                    Divider { width: rowLoader.width }
                }

                Component {
                    id: deviceComponent
                    DeviceRow {
                        device: wrapper.modelData.device
                        current: list.currentIndex === wrapper.index
                    }
                }
            }
        }
    }
}
