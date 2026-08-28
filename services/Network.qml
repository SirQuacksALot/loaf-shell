pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
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

    // --- WLAN als QR-Code teilen ---
    // WIFI:-URI-Standard (von Android/iOS-Kameras seit ~2017 nativ
    // erkannt, kein Anbieter-Standard nötig):
    // WIFI:T:<WPA|WEP|nopass>;S:<SSID>;P:<Passwort>;H:<bool>;; -
    // Sonderzeichen (\;,":) im SSID/Passwort werden mit \ escaped. Das
    // gespeicherte Passwort selbst liefert Quickshell.Networking NICHT
    // (nur Metadaten wie Signalstärke/Security-Typ) - nmcli -s liest das
    // Secret des angegebenen NetworkManager-Profils, ohne zusätzliche
    // Rechte, solange man selbst der verbindende User ist. Als
    // Profilname dient network.name (SSID) - passt im Normalfall
    // (NetworkManager benennt ein neues Profil standardmäßig nach der
    // SSID), nicht aber falls das Profil manuell umbenannt wurde.
    //
    // Das Passwort landet NIE als Prozess-Argument (wäre kurz per `ps`
    // durch andere Prozesse desselben Users einsehbar) - stattdessen per
    // FileView in eine Datei unter XDG_RUNTIME_DIR geschrieben (tmpfs,
    // nur für den eigenen User lesbar), `qrencode -r <Datei>` liest von
    // dort, die Datei wird direkt danach wieder gelöscht.
    signal qrReady(string path)
    signal qrFailed()

    readonly property string _qrDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/quickshell"
    readonly property string _qrInputPath: root._qrDir + "/wifi-qr-input.txt"
    readonly property string _qrOutputPath: root._qrDir + "/wifi-qr.png"

    function _escapeQr(s) {
        return s.replace(/([\\;,":])/g, "\\$1");
    }

    function generateWifiQr(network) {
        if (!network) {
            root.qrFailed();
            return;
        }
        qrPskProc.targetNetwork = network;
        qrPskProc.command = ["nmcli", "-s", "-g", "802-11-wireless-security.psk", "connection", "show", network.name];
        qrPskProc.running = true;
    }

    Process {
        id: qrMkdirProc
        command: ["mkdir", "-p", root._qrDir]
    }

    Process {
        id: qrPskProc
        property var targetNetwork: null
        stdout: StdioCollector {
            onStreamFinished: {
                const network = qrPskProc.targetNetwork;
                if (!network) return;
                const open = network.security === WifiSecurityType.Open;
                const wep = network.security === WifiSecurityType.StaticWep || network.security === WifiSecurityType.DynamicWep;
                const type = open ? "nopass" : (wep ? "WEP" : "WPA");
                const psk = this.text.trim();
                // Leeres Secret bei einem GESICHERTEN Netz = nmcli konnte
                // es nicht lesen (Profil nicht gefunden, Rechteproblem, ...)
                // - kein QR ohne Passwort ausgeben, der wäre für ein
                // Handy nutzlos/irreführend.
                if (!open && psk.length === 0) {
                    root.qrFailed();
                    return;
                }
                const ssid = root._escapeQr(network.name);
                const pass = open ? "" : root._escapeQr(psk);
                root._writeQrInput("WIFI:T:" + type + ";S:" + ssid + ";P:" + pass + ";;");
            }
        }
    }

    Component {
        id: _qrFileComponent
        FileView {
            printErrors: false
            onSaved: {
                qrEncodeProc.running = true;
                this.destroy();
            }
            onSaveFailed: {
                root.qrFailed();
                this.destroy();
            }
        }
    }

    function _writeQrInput(text) {
        const fv = _qrFileComponent.createObject(root, { path: root._qrInputPath });
        fv.setText(text);
    }

    Process {
        id: qrEncodeProc
        command: ["qrencode", "-r", root._qrInputPath, "-o", root._qrOutputPath, "-s", "6", "-m", "2"]
        onExited: exitCode => {
            // Eingabedatei mit dem Klartext-Passwort IMMER sofort wieder
            // löschen, unabhängig vom Ergebnis.
            qrCleanupProc.running = true;
            if (exitCode === 0) root.qrReady(root._qrOutputPath);
            else root.qrFailed();
        }
    }

    Process {
        id: qrCleanupProc
        command: ["rm", "-f", root._qrInputPath]
    }

    Component.onCompleted: qrMkdirProc.running = true
}
