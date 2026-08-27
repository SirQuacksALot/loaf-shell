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

    // Bild-Vorschauen: cliphist liefert in `list` für Bilder nur den
    // Platzhaltertext "[[ binary data ... ]]", die echten Pixel gibt's erst
    // über `cliphist decode <id>`. Damit nicht bei jedem Öffnen/Refresh neu
    // decodiert wird, landet das Ergebnis einmalig als PNG im Cache - Dateiname
    // ist die cliphist-id, die ist stabil solange der Eintrag existiert und
    // wird von cliphist nie wiederverwendet.
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/quickshell/clipboard-thumbs"
    property var _thumbRequested: ({})  // id -> true, verhindert doppeltes Decodieren

    signal thumbReady(string id)

    function thumbPath(entry) {
        return root.thumbDir + "/" + entry.id + ".png";
    }

    // Stößt das Decodieren für einen Bild-Eintrag an, falls noch nicht
    // geschehen. thumbReady(id) feuert, sobald die Datei fertig geschrieben
    // ist - die View hört darauf, um ihr Image neu zu laden.
    function ensureThumbnail(entry) {
        if (!entry || !entry.isImage) return;
        if (root._thumbRequested[entry.id]) return;
        root._thumbRequested[entry.id] = true;

        const path = root.thumbPath(entry);
        const proc = thumbProcComponent.createObject(root, {
            entryId: entry.id,
            command: ["sh", "-c", 'test -s "$1" || cliphist decode "$2" > "$1"', "_", path, entry.id]
        });
        proc.running = true;
    }

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
        id: mkThumbDirProc
        command: ["mkdir", "-p", root.thumbDir]
    }

    // Kurzlebiger, dynamisch erzeugter Process pro Thumbnail-Decode -
    // im Gegensatz zu copyProc/deleteProc/wipeProc kann hier mehr als ein
    // Aufruf gleichzeitig laufen (mehrere neue Bild-Einträge auf einmal).
    Component {
        id: thumbProcComponent
        Process {
            property string entryId
            onExited: exitCode => {
                if (exitCode !== 0) {
                    // Fehlgeschlagen (z.B. Eintrag zwischenzeitlich aus der
                    // cliphist-DB gefallen) - nächster ensureThumbnail-Aufruf
                    // darf es erneut versuchen.
                    delete root._thumbRequested[entryId];
                } else {
                    root.thumbReady(entryId);
                }
                destroy();
            }
        }
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
        command: ["sh", "-c", 'cliphist wipe; rm -rf "$1"', "_", root.thumbDir]
        onExited: root.refresh()
    }

    Component.onCompleted: {
        checkProc.running = true;
        mkThumbDirProc.running = true;
        root.refresh();
    }
}
