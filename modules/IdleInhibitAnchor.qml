import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services" as Services

// Hängt das Wayland-Idle-Inhibit-Protokoll (wlr-idle-inhibit-manager-v1)
// an ein eigenes, komplett unsichtbares 1x1-Fenster - IdleInhibitor
// braucht zwingend ein an ein echtes Surface gebundenes Fenster (siehe
// dessen `window`-Property), reine State-Logik (services/IdleInhibit.qml)
// reicht dafür nicht aus. Gleiches "einmal global, kein screen:"-Muster
// wie PolkitOverlay/OsdOverlay/AppLauncher (siehe shell.qml) - WELCHER
// Monitor das Fenster abbekommt ist hier völlig egal, es wird nie sichtbar.
//
// Hyprland/hypridle respektieren das Protokoll direkt auf Compositor-
// Ebene (ext-idle-notify-v1 prüft aktive Inhibitor-Surfaces automatisch,
// bevor es Sperr-/DPMS-Listener aus hypridle.conf feuert) - dafür ist
// KEINE Änderung an hypridle.conf nötig, im Unterschied zum alternativen
// Ansatz über systemd-inhibit/D-Bus (dort müsste hypridle den Lock erst
// abfragen).
Scope {
    id: root

    PanelWindow {
        id: anchor
        visible: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // 1x1 statt 0x0 - manche Compositor kommen mit einer Surface der
        // Größe 0 nicht zuverlässig klar.
        implicitWidth: 1
        implicitHeight: 1
        anchors { top: true; left: true }
    }

    IdleInhibitor {
        window: anchor
        enabled: Services.IdleInhibit.inhibited
    }
}
