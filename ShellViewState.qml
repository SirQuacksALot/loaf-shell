pragma Singleton
import Quickshell
import Quickshell.Io

// Erlaubt es, EINE BELIEBIGE Insel-View von außerhalb zu öffnen/schließen
// (z.B. per Hyprland-Keybind, siehe Submap "shell" in
// Configs/hyprland/.config/hypr/modules/bindings.lua) - ein einziger,
// generischer Signal-Kanal statt eines eigenen Singletons PRO View.
//
// War vorher 8 fast identische Dateien (ControlCenterState.qml,
// WallpaperPickerState.qml, PowerMenuState.qml, ClipboardState.qml,
// InfoState.qml, WifiState.qml, BluetoothState.qml, DefaultViewState.qml -
// jede nur `signal toggleRequested()` + `IpcHandler { target: "x";
// function toggle(): void { root.toggleRequested() } }`), dazu in
// IslandRoot.qml 8 fast identische `Connections`-Blöcke. Der Name der
// gewünschten View ist reine Nutzlast (ein QML-String), es gibt also
// keinen Grund, ihn stattdessen in 8 verschiedene IPC-Targets zu kodieren.
//
// BEWUSST NICHT für LauncherState.qml mit reingezogen - der Launcher ist
// kein "benannter Insel-View-Wechsel" (kein viewMode-Eintrag, kein
// toggleViewExternally()), sondern ein eigenständiges, globales Overlay-
// Fenster mit eigenem `open`-Bool (siehe dortiger Kommentar) - andere
// Zuständigkeit, bleibt deshalb ein eigenes Singleton.
//
// Testen: `qs ipc show` listet alle verfügbaren Targets/Funktionen.
// Aufruf z.B. `qs ipc call shell toggle wifi` - der übergebene Name muss
// exakt dem `name:`-Property der Ziel-View entsprechen (siehe
// modules/island/views/*.qml).
Singleton {
    id: root

    signal toggleRequested(string name)

    IpcHandler {
        target: "shell"
        function toggle(name: string): void { root.toggleRequested(name) }
    }
}
