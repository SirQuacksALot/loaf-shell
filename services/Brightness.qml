pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Bildschirmhelligkeit über brightnessctl (Quickshell hat kein eigenes
// Backlight-Modul). Setzen passiert optimistisch, ein Timer pollt danach
// zusätzlich nach - falls die Helligkeit extern geändert wird (z.B. über
// Tastatur-Funktionstasten, die selbst brightnessctl aufrufen).
//
// Der 4s-Poll-Abstand reicht für die normale Anzeige, ist aber für die OSD
// (services/Osd.qml/modules/OsdOverlay.qml) live spürbar zu träge - anders
// als Lautstärke (echte PipeWire-Events, siehe services/Audio.qml) gibt es
// für Helligkeit kein reaktives Backlight-API, ein Tastendruck auf die
// Helligkeits-Medientaste (ruft brightnessctl DIREKT über Hyprland auf,
// komplett an Quickshell vorbei, siehe bindings.lua) wurde bisher erst
// beim nächsten Poll-Tick bemerkt (live gemeldeter Bug: "OSD hängt bei
// Helligkeit komplett hinterher"). refresh() jetzt zusätzlich per IPC
// erreichbar, die Medientasten-Binds stoßen ihn direkt nach brightnessctl
// an, statt auf den Timer zu warten.
Singleton {
    id: root

    property bool available: false
    property real percentage: 1.0   // 0..1

    readonly property string iconName: {
        if (!available) return "sun-dim";
        if (percentage < 0.15) return "sun-dim";
        if (percentage < 0.6) return "sun-medium";
        return "sun";
    }

    readonly property string label: available ? Math.round(percentage * 100) + "%" : "–"

    function refresh() {
        getProc.running = true;
    }

    function setPercentage(v) {
        const clamped = Math.max(1, Math.min(100, Math.round(v * 100)));
        root.percentage = clamped / 100; // optimistisch, getProc bestätigt kurz danach
        setProc.command = ["brightnessctl", "set", clamped + "%"];
        setProc.running = true;
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // brightnessctl -m: "device,class,current,percent%,max"
    Process {
        id: getProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(",");
                if (parts.length >= 4) {
                    root.available = true;
                    root.percentage = parseInt(parts[3], 10) / 100;
                } else {
                    root.available = false;
                }
            }
        }
    }

    Process {
        id: setProc
        onExited: root.refresh()
    }

    // Testen: `qs ipc show` listet alle verfügbaren Targets/Funktionen.
    // Aufruf z.B. `qs ipc call brightness refresh` - siehe Kopfkommentar
    // + Configs/hyprland/.config/hypr/modules/bindings.lua
    // (XF86MonBrightnessUp/Down).
    IpcHandler {
        target: "brightness"
        function refresh(): void { root.refresh() }
    }
}
