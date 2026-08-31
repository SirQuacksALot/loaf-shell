pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Echtes VPN-Backend über NetworkManager/nmcli - kein eigener D-Bus-Client
// (anders als services/Network.qml/Bluetooth.qml, die Quickshells native
// Quickshell.Networking/Quickshell.Bluetooth-Module nutzen): dieses Modul
// kennt gar keinen VPN-Typ (siehe Prüfung beim Bau dieser Datei -
// quickshell-network.qmltypes enthält keine Vpn-Klasse). nmcli ist hier
// exakt das, was Network.qml schon für den WLAN-QR-Code nutzt (PSK per
// `nmcli -s ... show`) - dasselbe Werkzeug, nur als alleinige Datenquelle
// statt als Ergänzung.
//
// NUR OpenVPN ist bisher angebunden (NetworkManager-VPN-Profile vom Typ
// "vpn" mit vpn.service-type "...openvpn"). eduVPN ist strukturell schon
// vorbereitet (eduvpnConnections unten, per service-type gefiltert), bleibt
// aber leer, bis ein eduVPN-Client (eigenes NM-VPN-Plugin oder eigener
// D-Bus-Dienst) tatsächlich existiert - VpnView.qml zeigt den eduVPN-Reiter
// deshalb aktuell deaktiviert an.
//
// Mehrere VPN-Verbindungen können gleichzeitig aktiv sein (NetworkManager
// erlaubt das, anders als bei WLAN gibt es kein "nur eine Verbindung
// gleichzeitig") - connect()/disconnect() wirken deshalb NUR auf die
// jeweils angegebene Verbindung, nicht auf alle anderen.
Singleton {
    id: root

    // Jeder Eintrag: { id: <NM-UUID>, name, active, autoConnect,
    // fullTunnel, device, serviceType, kind: "openvpn"|"eduvpn"|"other" }
    property var connections: []

    readonly property var openvpnConnections: root.connections.filter(c => c.kind === "openvpn")
    // Immer leer, bis ein eduVPN-Client existiert (siehe Kopfkommentar) -
    // der Filter selbst ist aber schon korrekt, sodass ein künftiger
    // eduVPN-Import (vpn.service-type mit "eduvpn") ohne Änderung hier
    // sofort auftauchen würde.
    readonly property var eduvpnConnections: root.connections.filter(c => c.kind === "eduvpn")

    // UUIDs, für die gerade ein connect()/disconnect() läuft (Process noch
    // nicht beendet) - VpnView zeigt dafür einen Spinner statt
    // Verbunden/Getrennt, exakt wie BluetoothDevice.state es für
    // Pairing/Connecting tut.
    property var pendingIds: []
    function isPending(id) { return root.pendingIds.indexOf(id) >= 0; }
    function _setPending(id, on) {
        if (on) {
            if (!root.isPending(id)) root.pendingIds = root.pendingIds.concat([id]);
        } else {
            root.pendingIds = root.pendingIds.filter(p => p !== id);
        }
    }

    // Fehler aus einem fehlgeschlagenen Import/Connect/Disconnect/Modify -
    // ein einzelner String reicht (wie WifiView.connectError), da immer
    // nur eine Aktion gleichzeitig im Vordergrund der UI relevant ist.
    signal importFailed(string reason)
    signal importSucceeded(string name)
    signal actionFailed(string reason)

    // Namen, für die nach dem NÄCHSTEN abgeschlossenen refresh()-Durchlauf
    // geprüft werden soll, ob sie tatsächlich in root.connections
    // aufgetaucht sind (siehe importFile()/_finishRefresh() unten) - ein
    // einfaches Property statt eines dynamischen signal.connect(closure)
    // auf ein extra "refreshed()"-Signal: DAS hatte sich live als zerbrechlich
    // erwiesen (ReferenceError: root is not defined, alle 4s wiederholt) -
    // ein Hot-Reload MITTEN in der Wartezeit hat den alten, noch verbundenen
    // Closure verwaist zurückgelassen, der sich selbst danach nie wieder
    // abmelden konnte (sein eigener Abmelde-Aufruf warf ja denselben
    // Fehler). Ein Property auf root selbst hat dieses Problem nicht - es
    // lebt und stirbt exakt mit dem Singleton, keine separate Signal-
    // Verbindung, die das überleben könnte.
    property var _pendingImportChecks: []

    // Läuft nur, solange die VPN-View offen ist - exakt dasselbe Muster
    // wie Network.setWifiScanning()/Bluetooth.setDiscovering() (kein
    // Dauerpolling im Hintergrund). NetworkManager selbst gibt keine
    // Live-Change-Signale her, die nmcli uns reichen könnte, ohne D-Bus
    // direkt zu sprechen - Polling ist hier der pragmatische Weg.
    property bool polling: false
    function setPolling(enabled) {
        if (root.polling === enabled) return;
        root.polling = enabled;
        if (enabled) root.refresh();
    }

    Timer {
        interval: 4000
        repeat: true
        running: root.polling
        onTriggered: root.refresh()
    }

    // Läuft nie zwei Mal gleichzeitig: refresh() wird von mehreren
    // Stellen quasi zeitgleich ausgelöst (Polling-Timer, jeder
    // erfolgreiche/fehlgeschlagene connect()/disconnect()/importFile(),
    // ...) - listProc/detailProc unten sind aber JEWEILS ein einzelner,
    // geteilter Process, kein Pool. Ein zweiter refresh(), während der
    // erste noch läuft, würde detailProc.queue/.results mitten in der
    // Verarbeitung überschreiben (live beobachtet: bei mehreren schnell
    // hintereinander importierten Verbindungen blieb die Liste leer/
    // inkonsistent, weil sich mehrere Durchläufe gegenseitig
    // überschrieben haben). Läuft schon einer, wird stattdessen nur
    // _refreshPending gesetzt - _finishRefresh() startet dann GENAU EINEN
    // weiteren Durchlauf, sobald der aktuelle fertig ist (nicht mehrere
    // gestapelte, ein einziger Nachzügler reicht, um den letzten Stand
    // einzusammeln).
    property bool _refreshing: false
    property bool _refreshPending: false

    function refresh() {
        if (root._refreshing) {
            root._refreshPending = true;
            return;
        }
        root._refreshing = true;
        listProc.running = true;
    }

    function _finishRefresh() {
        root._refreshing = false;
        if (root._pendingImportChecks.length > 0) {
            const checks = root._pendingImportChecks;
            root._pendingImportChecks = [];
            for (const c of checks) {
                if (root.connections.some(conn => conn.name === c)) root.importSucceeded(c);
                else root.importFailed("Verbindung wurde importiert, taucht aber nicht in der Liste auf - VPN-Ansicht neu öffnen.");
            }
        }
        if (root._refreshPending) {
            root._refreshPending = false;
            root.refresh();
        }
    }

    // Schritt 1: Übersicht aller NM-Profile - NAME/UUID/TYPE/ACTIVE sind
    // Standard-Overview-Felder (siehe `nmcli connection show`), TYPE ist
    // für importierte OpenVPN-Profile schlicht "vpn" (der konkrete Client
    // steckt erst in vpn.service-type, das die Overview NICHT liefert -
    // Schritt 2 unten holt das pro Verbindung nach).
    Process {
        id: listProc
        command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().length > 0 ? this.text.trim().split("\n") : [];
                const items = [];
                for (const line of lines) {
                    // War ein regex-Split mit negativem Lookbehind
                    // (/(?<!\\):/), um von nmcli escapte ':' innerhalb
                    // eines Feldwerts nicht als Trenner zu behandeln - Qt's
                    // QML-JS-Engine matched das aber live nachweislich NIE
                    // (console.warn zeigte "vpn items=0", obwohl die Zeile
                    // nachweislich da war - vermutlich fehlende/kaputte
                    // Lookbehind-Unterstützung). Schlichtes Split auf ':'
                    // reicht hier ohnehin: NAME kann zwar theoretisch einen
                    // escapten ':' enthalten, TYPE/ACTIVE (die einzigen
                    // Felder, die wir tatsächlich auswerten) nie - ein
                    // Doppelpunkt im Namen würde höchstens `name` selbst
                    // falsch zusammensetzen, nicht aber die type/active-
                    // Erkennung verfälschen.
                    const parts = line.split(":");
                    if (parts.length < 4) continue;
                    const [name, uuid, type] = parts;
                    const active = parts[3] === "yes";
                    if (type !== "vpn") continue;
                    items.push({ name, uuid, active });
                }
                if (items.length === 0) {
                    root.connections = [];
                    root._finishRefresh();
                    return;
                }
                tunProc.pendingItems = items;
                tunProc.running = true;
            }
        }
    }

    // Zwischenschritt: das tatsächliche tun/tap-Gerät finden, das eine
    // aktive VPN-Verbindung gerade nutzt. NICHT über
    // `connection show <uuid>`/GENERAL.DEVICES lösbar - das liefert live
    // nachweislich das TRÄGER-Interface (z.B. wlan0, über das der Tunnel
    // läuft), nicht das vom VPN erzeugte tun-Gerät (per `nmcli -t -f
    // NAME,TYPE,DEVICE connection show --active` UND per GENERAL.DEVICES
    // bestätigt - beide zeigten "wlan0" statt "tun0"). Das tun-Gerät
    // taucht in NetworkManagers Modell als eigenes, unabhängiges "externally
    // managed" Device mit einem AUTOGENERIERTEN eigenen Verbindungsnamen
    // auf (z.B. "tun0"), der NICHT dem VPN-Profilnamen entspricht - nmclis
    // CLI bietet keine direkte Zuordnung "dieses tun-Gerät gehört zu jener
    // VPN-Verbindung". Pragmatischer Ausweg: ist GENAU EINE VPN-Verbindung
    // aktiv UND GENAU EIN tun/tap-Gerät verbunden, ist die Zuordnung
    // eindeutig. Bei mehreren gleichzeitig aktiven VPNs bleibt `device`
    // leer (keine Statistik-Kachel statt einer möglicherweise falschen
    // Zuordnung) - der Preis für simple, CLI-only Diagnose.
    Process {
        id: tunProc
        property var pendingItems: []
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().length > 0 ? this.text.trim().split("\n") : [];
                const tunDevices = [];
                for (const line of lines) {
                    const parts = line.split(":");
                    if (parts.length < 3) continue;
                    const [device, type, state] = parts;
                    if ((type === "tun" || type === "tap") && state.startsWith("connected")) tunDevices.push(device);
                }
                const activeCount = tunProc.pendingItems.filter(i => i.active).length;
                const soleDevice = (activeCount === 1 && tunDevices.length === 1) ? tunDevices[0] : "";
                detailProc.start(tunProc.pendingItems, soleDevice);
            }
        }
    }

    // Schritt 2: pro VPN-Profil die Detail-Felder nachladen - sequenziell
    // statt N parallele Process-Instanzen (einfacher zu verfolgen, und
    // nmcli-Aufrufe sind ohnehin schnell genug, dass das nicht spürbar
    // langsamer ist).
    Process {
        id: detailProc
        property var queue: []
        property var results: []
        property string resolvedDevice: ""

        function start(items, resolvedDevice) {
            detailProc.queue = items;
            detailProc.results = [];
            detailProc.resolvedDevice = resolvedDevice || "";
            detailProc._next();
        }

        function _next() {
            if (detailProc.queue.length === 0) {
                root.connections = detailProc.results;
                root._finishRefresh();
                return;
            }
            // "id" als Selektor erwartet den VERBINDUNGSNAMEN, keine UUID
            // (live mit `nmcli connection show id <uuid>` verifiziert:
            // "Verbindungsprofil existiert nicht", obwohl die UUID
            // tatsächlich existierte) - "uuid" ist der richtige Selektor
            // für das, was hier gespeichert ist.
            detailProc.command = ["nmcli", "-t", "-g",
                "vpn.service-type,ipv4.never-default,connection.autoconnect",
                "connection", "show", "uuid", detailProc.queue[0].uuid];
            detailProc.running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const item = detailProc.queue.shift();
                if (!item) return;
                const lines = this.text.split("\n");
                const serviceType = (lines[0] || "").trim();
                // ipv4.never-default "yes" = diese Verbindung darf NIE
                // zur Standardroute werden (Split-Tunnel: nur vom Server
                // gepushte Routen laufen durch den Tunnel) - "no"
                // (Standard) erlaubt NetworkManager, eine vom Server
                // gepushte 0.0.0.0/0-Route zu übernehmen (voller Tunnel).
                // Exakt der Schalter hinter GNOMEs "Nur für Ressourcen in
                // diesem Netzwerk verwenden"-Checkbox.
                const neverDefault = (lines[1] || "no").trim() === "yes";
                const autoConnect = (lines[2] || "no").trim() === "yes";
                // Nur der aktiven Verbindung das aufgelöste tun-Gerät
                // zuweisen (siehe tunProc oben) - bei mehreren aktiven
                // VPNs ist detailProc.resolvedDevice ohnehin leer.
                const device = item.active ? detailProc.resolvedDevice : "";
                let kind = "other";
                if (serviceType.includes("openvpn")) kind = "openvpn";
                else if (serviceType.includes("eduvpn")) kind = "eduvpn";
                detailProc.results.push({
                    id: item.uuid, name: item.name, active: item.active,
                    autoConnect, fullTunnel: !neverDefault, device,
                    serviceType, kind
                });
                detailProc._next();
            }
        }
    }

    // Gemeinsamer Unterbau für alle "feuern, auf Erfolg/Fehler reagieren,
    // danach neu laden"-Aktionen (connect/disconnect/modify/forget) -
    // dynamisch erzeugt statt eines einzelnen statischen Process (wie
    // qrPskProc in Network.qml), weil mehrere Aktionen für
    // UNTERSCHIEDLICHE Verbindungen fast gleichzeitig ausgelöst werden
    // können (z.B. zwei Toggle-Klicks kurz hintereinander) - ein
    // wiederverwendeter Process würde den zweiten Aufruf sonst
    // verschlucken/den ersten abbrechen.
    Component {
        id: _actionProcComponent
        Process {
            property var onDone: null
            stderr: StdioCollector {}
            onExited: exitCode => {
                if (this.onDone) this.onDone(exitCode === 0, this.stderr.text.trim());
                root.refresh();
                this.destroy();
            }
        }
    }

    function _runAction(cmd, onDone) {
        const p = _actionProcComponent.createObject(root, { command: cmd, onDone: onDone || null });
        p.running = true;
    }

    function connect(id) {
        root._setPending(id, true);
        root._runAction(["nmcli", "connection", "up", "uuid", id], (ok, err) => {
            root._setPending(id, false);
            if (!ok) root.actionFailed(err);
        });
    }

    function disconnect(id) {
        root._setPending(id, true);
        root._runAction(["nmcli", "connection", "down", "uuid", id], (ok, err) => {
            root._setPending(id, false);
            if (!ok) root.actionFailed(err);
        });
    }

    function setAutoStart(id, on) {
        root._runAction(["nmcli", "connection", "modify", "uuid", id,
            "connection.autoconnect", on ? "yes" : "no"], (ok, err) => {
            if (!ok) root.actionFailed(err);
        });
    }

    // on=true -> voller Tunnel (never-default=no, siehe detailProc-
    // Kommentar oben). ipv6 auf denselben Wert mitgesetzt, damit beide
    // Familien konsistent bleiben - ein IPv6-Leck am Split-Tunnel vorbei
    // wäre sonst möglich, selbst wenn der Nutzer "Split-Tunnel" gewählt hat.
    function setFullTunnel(id, on) {
        root._runAction(["nmcli", "connection", "modify", "uuid", id,
            "ipv4.never-default", on ? "no" : "yes",
            "ipv6.never-default", on ? "no" : "yes"], (ok, err) => {
            if (!ok) root.actionFailed(err);
        });
    }

    function forget(id) {
        root._runAction(["nmcli", "connection", "delete", "uuid", id], (ok, err) => {
            if (!ok) root.actionFailed(err);
        });
    }

    // Per Drag&Drop abgelegte .ovpn-Datei importieren (siehe VpnView.qml/
    // DropArea unten) - `nmcli connection import` liest die Datei direkt
    // von ihrem aktuellen Ort, kopiert sie intern nach
    // /etc/NetworkManager/system-connections/, ein manuelles Kopieren
    // vorher ist nicht nötig. Läuft über Polkit, falls nötig (dieselbe
    // Authentifizierung, die modules/PolkitOverlay.qml bereits für andere
    // privilegierte Aktionen abfängt).
    // nmcli benennt eine importierte Verbindung nach dem Dateinamen ohne
    // Endung (live verifiziert: "machines_eu-dedivip-4.ovpn" ->
    // "machines_eu-dedivip-4") - reicht als Vorab-Check auf "gibt es
    // schon", OHNE nmcli dafür extra aufzurufen. Kein Ersatz für einen
    // echten Lock (root.connections kann seit dem letzten refresh() leicht
    // veraltet sein), aber genau der Fall, den der Nutzer meldete
    // (dieselbe Datei mehrfach hintereinander reingezogen) fängt das
    // zuverlässig ab.
    function _connectionNameForFile(path) {
        const base = path.split("/").pop();
        const dot = base.lastIndexOf(".");
        return dot > 0 ? base.slice(0, dot) : base;
    }

    Component {
        id: _importProcComponent
        Process {
            property string path: ""
            property string expectedName: ""
            stdout: StdioCollector {}
            stderr: StdioCollector {}
            Component.onCompleted: this.command = ["nmcli", "connection", "import", "type", "openvpn", "file", this.path]
            onExited: exitCode => {
                if (exitCode !== 0) {
                    root.importFailed(this.stderr.text.trim() || this.stdout.text.trim());
                    root.refresh();
                    this.destroy();
                    return;
                }
                // Erfolg erst melden, sobald die neue Verbindung nach
                // einem VOLLSTÄNDIGEN refresh()-Durchlauf tatsächlich in
                // root.connections auftaucht - ein "Importiert"-Hinweis
                // direkt beim nmcli-Exitcode 0 kam sonst an, während die
                // Liste selbst (noch) leer war. _pendingImportChecks statt
                // signal.connect(closure), siehe Kopfkommentar dort.
                root._pendingImportChecks = root._pendingImportChecks.concat([this.expectedName]);
                root.refresh();
                this.destroy();
            }
        }
    }

    function importFile(path) {
        if (!path) return;
        const expectedName = root._connectionNameForFile(path);
        if (root.connections.some(c => c.name === expectedName)) {
            root.importFailed("Eine Verbindung namens \"" + expectedName + "\" existiert bereits.");
            return;
        }
        const p = _importProcComponent.createObject(root, { path, expectedName });
        p.running = true;
    }

    Component.onCompleted: root.refresh()
}
