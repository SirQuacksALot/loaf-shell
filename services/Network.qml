pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Networking

// Wrapper um Quickshells eingebautes Networking-Modul (NetworkManager via
// D-Bus - kein nmcli-Polling mehr nötig, das gab's hier nur, weil dieses
// Modul beim ursprünglichen Schreiben von Network.qml offenbar übersehen
// wurde). Liefert live Property-Bindings statt gepollter Prozess-Ausgabe:
// sofortige Updates bei Scan-Ergebnissen, Verbindungsauf-/-abbau etc.
Singleton {
    id: root

    // Erstes Wifi- bzw. Wired-Device, falls vorhanden (mehrere Adapter
    // theoretisch möglich, hier aber nicht relevant - dieses Setup hat
    // jeweils genau einen).
    readonly property var wifiDevice: {
        for (const d of Networking.devices.values) if (d.type === DeviceType.Wifi) return d;
        return null;
    }
    readonly property var wiredDevice: {
        for (const d of Networking.devices.values) if (d.type === DeviceType.Wired) return d;
        return null;
    }

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiHardwareEnabled: Networking.wifiHardwareEnabled

    // Verfügbare Netze des Wifi-Devices, verbunden zuerst, danach nach
    // Signalstärke absteigend - fürs Verbinden interessant sind erst das
    // aktive, dann die stärksten Netze.
    readonly property var wifiNetworks: {
        if (!root.wifiDevice) return [];
        const list = [...root.wifiDevice.networks.values];
        list.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
        return list;
    }

    readonly property var activeWifiNetwork: root.wifiNetworks.find(n => n.connected) || null

    // --- Bestehende, projektweit genutzte API bleibt erhalten (Control
    // Center-Icon, InfoView-Statuszeile) - nur die Datenquelle ist jetzt
    // das native Modul statt nmcli. ---
    readonly property string kind: {
        if (root.wiredDevice && root.wiredDevice.connected) return "ethernet";
        if (root.wifiDevice && root.wifiDevice.connected) return "wifi";
        return "disconnected";
    }
    readonly property string connectionName: {
        if (root.kind === "wifi") return root.activeWifiNetwork ? root.activeWifiNetwork.name : "";
        if (root.kind === "ethernet") return root.wiredDevice.name;
        return "";
    }
    // WifiNetwork.signalStrength liefert einen Bruch (0.0-1.0), keinen
    // Prozentwert - live per Diagnose bestätigt (signalStrength=1 bei
    // voller Signalstärke, nicht 100). Mal 100 für eine gewohnte
    // Prozentanzeige.
    readonly property int signalStrength: root.activeWifiNetwork ? Math.round(root.activeWifiNetwork.signalStrength * 100) : 0

    readonly property string iconName: {
        if (root.kind === "wifi") return root.signalStrength < 40 ? "wifi-off" : "wifi";
        if (root.kind === "ethernet") return "ethernet-port";
        return "wifi-off";
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    // An/aus mit dem Scannen fürs WifiView - läuft nur, während die View
    // offen ist (siehe dort onActiveChanged), spart Funk-Aktivität im
    // Hintergrund.
    function setWifiScanning(enabled) {
        if (root.wifiDevice) root.wifiDevice.scannerEnabled = enabled;
    }
}
