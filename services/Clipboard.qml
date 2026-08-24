pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Zwischenablage-Verlauf über cliphist (https://github.com/sentriz/cliphist).
// cliphist selbst füllt sich nur, wenn `wl-paste --watch cliphist store`
// im Hintergrund läuft (Autostart, siehe hyprland-Config) - dieser Service
// liest/steuert nur, sammelt nicht selbst.
//
// `cliphist list` gibt pro Zeile "<id>\t<vorschau>" aus. Für decode/delete
// erwartet cliphist genau diese Zeile über STDIN zurück (nicht nur die id -
// siehe `cliphist list | fzf | cliphist decode`). Deshalb wird hier immer
// die komplette Rohzeile gespeichert und beim Kopieren/Löschen per
// Process.write() zurückgereicht - Process.write() statt Shell-String-
// Interpolation, damit Sonderzeichen in der Vorschau (Anführungszeichen
// etc.) keine Shell-Escaping-Probleme verursachen können.
Singleton {
    id: root

    readonly property bool available: checkProc.checked ? checkProc.found : true
    property var entries: []   // [{ id, raw, preview, isImage }]

    function refresh() {
        listProc.running = true;
    }

    // Setzt einen früheren Eintrag wieder als aktuellen Klemmbrett-Inhalt.
    // stdinEnabled wird hier bei JEDEM Aufruf explizit neu auf true
    // gesetzt (nicht nur einmalig deklarativ) - laut Doku bleibt der
    // Stdin-Kanal nach dem Schließen für die jeweilige Prozess-Instanz
    // dauerhaft zu, "auch wenn wieder auf true gesetzt". Sicherheitshalber
    // also vor JEDEM neuen Lauf frisch öffnen, statt uns auf den Zustand
    // vom letzten Mal zu verlassen.
    function copyEntry(entry) {
        if (!entry) return;
        copyProc.pendingWrite = entry.raw;
        copyProc.stdinEnabled = true;
        copyProc.running = true;
    }

    function deleteEntry(entry) {
        if (!entry) return;
        deleteProc.pendingWrite = entry.raw;
        deleteProc.stdinEnabled = true;
        deleteProc.running = true;
    }

    function wipeAll() {
        wipeProc.running = true;
    }

    Process {
        id: checkProc
        property bool checked: false
        property bool found: false
        command: ["sh", "-c", "command -v cliphist"]
        onExited: exitCode => { checkProc.found = exitCode === 0; checkProc.checked = true; }
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n").filter(l => l.length > 0);
                root.entries = lines.map(line => {
                    const tab = line.indexOf("\t");
                    const id = tab >= 0 ? line.slice(0, tab) : line;
                    const preview = tab >= 0 ? line.slice(tab + 1) : "";
                    return {
                        id: id,
                        raw: line,
                        // Gecappt - ein einzelner riesiger Textblock im
                        // Verlauf soll die Vorschau (eh nur einzeilig mit
                        // Ellipsis angezeigt, siehe ClipboardView.qml)
                        // nicht unnötig aufblähen.
                        preview: preview.slice(0, 5000),
                        isImage: /binary data/i.test(preview)
                    };
                });
            }
        }
    }

    // pendingWrite wird erst geschrieben, sobald der Prozess wirklich
    // läuft (onRunningChanged statt direkt bei running=true - der
    // Prozess braucht einen Moment zum Starten, ein write() davor ginge
    // ins Leere).
    Process {
        id: copyProc
        property string pendingWrite: ""
        command: ["sh", "-c", "cliphist decode | wl-copy"]
        stdinEnabled: true
        onRunningChanged: if (running) {
            copyProc.write(copyProc.pendingWrite);
            copyProc.stdinEnabled = false;
        }
    }

    Process {
        id: deleteProc
        property string pendingWrite: ""
        command: ["cliphist", "delete"]
        stdinEnabled: true
        onRunningChanged: if (running) {
            deleteProc.write(deleteProc.pendingWrite);
            deleteProc.stdinEnabled = false;
        }
        onExited: root.refresh()
    }

    Process {
        id: wipeProc
        command: ["cliphist", "wipe"]
        onExited: root.refresh()
    }

    Component.onCompleted: {
        checkProc.running = true;
        root.refresh();
    }
}
