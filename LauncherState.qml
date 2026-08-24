pragma Singleton
import Quickshell
import Quickshell.Io

// Zentraler Zustand für den AppLauncher, damit sowohl das Dock-Icon
// als auch externe Trigger (Tastenkürzel) ihn öffnen/schließen können.
Singleton {
    id: root

    property bool open: false

    function toggle() { root.open = !root.open }
    function show()   { root.open = true }
    function hide()   { root.open = false }

    // Erlaubt es, den Launcher von außerhalb von QuickShell zu steuern,
    // z.B. über einen Tastenkürzel-Bind deines Compositors:
    //
    //   qs ipc call launcher toggle
    //
    // Funktioniert unabhängig vom Compositor (Hyprland, Sway, niri, ...).
    // Testen: `qs ipc show` listet alle verfügbaren Targets/Funktionen.
    IpcHandler {
        target: "launcher"

        function toggle(): void { root.toggle() }
        function open(): void { root.show() }
        function close(): void { root.hide() }
    }
}
