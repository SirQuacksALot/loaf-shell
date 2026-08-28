pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Netzwerk-Diagnose (Durchsatz, Ping/Paketverlust) für die Detail-Anzeige
// in WifiView.qml. BEWUSST unabhängig von services/Network.qml - Services
// hängen in diesem Projekt nicht voneinander ab (siehe Kopfkommentar
// Localization.qml, "Services sind reine Logik-Singletons"), das Interface
// bekommt dieser Service von außen über setInterface() gereicht, die View
// verdrahtet beide.
//
// Läuft komplett nur, solange measuring true ist (siehe setMeasuring()) -
// kein Dauer-Ping/Polling im Hintergrund, exakt wie WLAN-Scanning
// (Services.Network.setWifiScanning) oder Bluetooth-Discovery
// (Services.Bluetooth.setDiscovering) es schon vormachen.
Singleton {
    id: root

    property string interfaceName: ""
    property bool measuring: false

    // --- Durchsatz ---
    // rx/txBytes: Gesamtsumme seit das Interface aktiv ist (kommt direkt
    // aus dem Kernel-Zähler unter /sys/class/net/<iface>/statistics/ -
    // NICHT seit die View offen ist, der Zähler läuft unabhängig davon
    // weiter und wird erst beim Interface-Neustart zurückgesetzt).
    // rx/txRate: Byte/s zwischen den letzten zwei Samples (1s-Takt) -
    // die eigentliche "live"-Momentaufnahme.
    property real rxBytes: 0
    property real txBytes: 0
    property real rxRate: 0
    property real txRate: 0
    property real _lastRx: -1
    property real _lastTx: -1

    // --- Ping/Paketverlust ---
    // Fester externer Host statt Gateway-Lookup - testet die komplette
    // Strecke bis ins Internet (das, was man mit "ist mein WLAN lahm"
    // typischerweise meint), ohne den Router per D-Bus/route-Tabelle
    // erst ermitteln zu müssen. 1.1.1.1 (Cloudflare) statt eines
    // Domainnamens - kein DNS-Lookup nötig, der bei einem WLAN-Problem
    // selbst schon scheitern könnte.
    readonly property string pingHost: "1.1.1.1"
    property real latencyMs: -1   // -1 = noch kein Ergebnis
    property int pingsSent: 0
    property int pingsLost: 0
    readonly property real packetLoss: root.pingsSent > 0 ? root.pingsLost / root.pingsSent : 0

    // Echte IPv4 (NICHT die MAC - Quickshell.Networking's NetworkDevice.
    // address ist die Hardware-Adresse, keine IP, live am System
    // verifiziert). `ip` selbst übersetzt seine Feldnamen ("inet", ...)
    // nicht, anders als `ping` unten also kein Locale-Problem.
    property string ipAddress: ""

    function setInterface(name) {
        if (root.interfaceName === name) return;
        root.interfaceName = name;
        // Alte Rate-Berechnung würde sonst kurz einen Fantasiewert
        // zeigen (Differenz zwischen dem letzten Sample des ALTEN und
        // dem ersten Sample des NEUEN Interfaces).
        root._lastRx = -1;
        root._lastTx = -1;
        root.ipAddress = "";
    }

    // Paketverlust/Latenz zählen ab hier neu (kein "seit Interface aktiv"-
    // Äquivalent möglich - anders als rx/txBytes gibt es dafür keinen
    // laufenden Kernel-Zähler, nur was WIR selbst seit Messbeginn pingen).
    function setMeasuring(enabled) {
        if (root.measuring === enabled) return;
        root.measuring = enabled;
        if (enabled) {
            root.pingsSent = 0;
            root.pingsLost = 0;
            root.latencyMs = -1;
            pingProc.running = true;
        } else {
            pingProc.running = false;
        }
    }

    function formatBytes(bytes) {
        if (bytes <= 0) return "0 B";
        const units = ["B", "KB", "MB", "GB", "TB"];
        let value = bytes;
        let i = 0;
        while (value >= 1024 && i < units.length - 1) {
            value /= 1024;
            i++;
        }
        return (i === 0 ? Math.round(value) : value.toFixed(1)) + " " + units[i];
    }

    function formatRate(bytesPerSecond) {
        return root.formatBytes(bytesPerSecond) + "/s";
    }

    Timer {
        id: statsTimer
        interval: 1000
        repeat: true
        running: root.measuring && root.interfaceName.length > 0
        triggeredOnStart: true
        onTriggered: statsProc.running = true
    }

    // `cat` zweier sysfs-Dateien statt eines Process pro Datei - ein
    // Aufruf, eine Ausgabe (zwei Zeilen), spart den doppelten
    // Prozessstart jede Sekunde.
    Process {
        id: statsProc
        command: ["cat",
            "/sys/class/net/" + root.interfaceName + "/statistics/rx_bytes",
            "/sys/class/net/" + root.interfaceName + "/statistics/tx_bytes"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                if (lines.length < 2) return;
                const rx = parseInt(lines[0], 10);
                const tx = parseInt(lines[1], 10);
                if (isNaN(rx) || isNaN(tx)) return;
                if (root._lastRx >= 0) {
                    // Math.max gegen einen negativen Ausreißer, falls das
                    // Interface zwischen zwei Samples neu gestartet wurde
                    // (Zähler wieder bei 0) - eine negative "Rate" wäre
                    // unsinnig, 0 ist der ehrlichereZwischenzustand.
                    root.rxRate = Math.max(0, rx - root._lastRx);
                    root.txRate = Math.max(0, tx - root._lastTx);
                }
                root._lastRx = rx;
                root._lastTx = tx;
                root.rxBytes = rx;
                root.txBytes = tx;
            }
        }
    }

    // IP-Adresse seltener nachziehen als rx/tx (5s statt 1s) - ändert
    // sich quasi nie, ein eigener `ip`-Aufruf jede Sekunde wäre unnötig.
    Timer {
        id: ipTimer
        interval: 5000
        repeat: true
        running: root.measuring && root.interfaceName.length > 0
        triggeredOnStart: true
        onTriggered: ipProc.running = true
    }

    Process {
        id: ipProc
        command: ["ip", "-4", "-o", "addr", "show", "dev", root.interfaceName]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = this.text.match(/inet (\d+\.\d+\.\d+\.\d+)/);
                root.ipAddress = match ? match[1] : "";
            }
        }
    }

    // Ein dauerhaft laufender `ping`-Prozess statt eines Einzelaufrufs im
    // Sekundentakt - spart den Prozessstart-Overhead UND liefert einen
    // fortlaufenden Strom, den SplitParser zeilenweise auswertet.
    //
    // `env LC_ALL=C` davor ist KEIN Versehen: bei deutscher System-
    // Locale übersetzt ping seine Ausgabe teilweise (u.a. "time=" wird
    // zu "Zeit=", live am System bestätigt) - die Regex unten hätte
    // dadurch NIE gematcht, Latenz/Paketverlust wären für immer leer
    // geblieben, ohne dass der Prozess selbst einen Fehler geworfen
    // hätte. LC_ALL=C erzwingt die unlokalisierte (englische) Ausgabe,
    // unabhängig davon, welche Sprache das System sonst nutzt.
    Process {
        id: pingProc
        command: ["env", "LC_ALL=C", "ping", "-i", "2", root.pingHost]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const match = line.match(/time=([\d.]+)/);
                if (match) {
                    root.pingsSent++;
                    root.latencyMs = parseFloat(match[1]);
                } else if (line.includes("Unreachable") || line.includes("timeout")) {
                    root.pingsSent++;
                    root.pingsLost++;
                }
            }
        }
    }
}
