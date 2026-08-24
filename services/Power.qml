pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Power-Menu-Aktionen. Sperren ist optional (nur verfügbar, wenn hyprlock
// oder swaylock installiert sind) - prüft das einmalig beim Start, genau
// wie NightLight.qml das mit hyprsunset macht.
Singleton {
    id: root

    property bool checked: false
    property bool lockAvailable: false
    property string lockCommand: ""

    Component.onCompleted: checkProc.running = true

    function lock() {
        if (!root.lockAvailable) return
        lockProc.command = [root.lockCommand]
        lockProc.startDetached()
    }

    function logout() {
        logoutProc.running = true
    }

    function reboot() {
        rebootProc.running = true
    }

    function shutdown() {
        shutdownProc.running = true
    }

    Process {
        id: checkProc
        command: ["sh", "-c", "command -v hyprlock || command -v swaylock"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = this.text.trim()
                root.lockAvailable = path.length > 0
                root.lockCommand = path.endsWith("swaylock") ? "swaylock" : "hyprlock"
                root.checked = true
            }
        }
    }

    Process { id: lockProc }
    Process { id: logoutProc; command: ["hyprctl", "dispatch", "exit"] }
    Process { id: rebootProc; command: ["systemctl", "reboot"] }
    Process { id: shutdownProc; command: ["systemctl", "poweroff"] }
}
