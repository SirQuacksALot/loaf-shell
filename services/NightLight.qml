pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Nachtmodus über hyprsunset (Hyprland). Prüft beim Start, ob das Binary
// überhaupt vorhanden ist, und markiert sich sonst als "available: false" -
// das Control-Center-Icon wird dann nur ausgegraut statt kaputt zu sein.
//
// Läufst du unter niri statt Hyprland, ist gammastep die dort empfohlene
// Alternative (siehe Tide-Island-README) - dann hier einfach "hyprsunset"
// durch "gammastep" ersetzen bzw. beide Fälle unterscheiden.
Singleton {
    id: root

    property bool checked: false
    property bool available: false
    property bool active: false

    readonly property string iconName: active ? "moon-star" : "moon"

    Component.onCompleted: checkProc.running = true

    function toggle() {
        if (!root.available) return;
        if (root.active) {
            killProc.running = true;
        } else {
            spawnProc.command = ["hyprsunset"];
            spawnProc.startDetached();
        }
        root.active = !root.active; // optimistisch, pollTimer bestätigt kurz danach
        pollTimer.restart();
    }

    function refresh() {
        pollProc.running = true;
    }

    Process {
        id: checkProc
        command: ["sh", "-c", "command -v hyprsunset"]
        onExited: exitCode => {
            root.available = exitCode === 0;
            root.checked = true;
            if (root.available) root.refresh();
        }
    }

    Process {
        id: spawnProc
    }

    Process {
        id: killProc
        command: ["pkill", "-x", "hyprsunset"]
    }

    Process {
        id: pollProc
        command: ["pgrep", "-x", "hyprsunset"]
        onExited: exitCode => root.active = exitCode === 0
    }

    Timer {
        id: pollTimer
        interval: 1000
        onTriggered: root.refresh()
    }

    Timer {
        interval: 15000
        running: root.available
        repeat: true
        onTriggered: root.refresh()
    }
}
