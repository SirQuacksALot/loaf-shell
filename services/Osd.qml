pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Zustand für die OSD-Popups (Lautstärke/Helligkeit + welche Hyprland-
// Submap gerade aktiv ist) - siehe modules/OsdOverlay.qml für die
// eigentliche Darstellung. `channel` ist EIN einziger Slot statt eines
// Stapels: kommt eine neue Änderung rein, während schon eine andere OSD
// sichtbar ist, wird sie einfach ersetzt - kommt in der Praxis kaum
// gleichzeitig vor, ein Stapel mehrerer OSDs wäre für eine kleine
// Insel-Pille ohnehin unpraktisch.
Singleton {
    id: root

    // "" | "volume" | "brightness" | "submap"
    property string channel: ""

    // Aktuell aktive Hyprland-Submap (leer = keine, siehe
    // Configs/hyprland/.config/hypr/modules/bindings.lua). Kommt direkt aus
    // Hyprlands eigenem rawEvent - KEIN eigener Hyprland-seitiger
    // Bind/IPC-Call nötig (anders als bei den Insel-View-Togglern, siehe
    // ShellViewState.qml): Hyprland meldet Submap-Wechsel von sich aus über
    // sein Event-Socket (Event-Name "submap", event.data = Submap-Name,
    // leer bei "reset"). Live verifiziert per `hyprctl dispatch
    // 'hl.dsp.submap("shell")'` + Log-Check, bevor das hier gebaut wurde.
    property string submapName: ""

    readonly property int displayDuration: 1500

    function _show(ch) {
        root.channel = ch
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: root.displayDuration
        onTriggered: root.channel = ""
    }

    // Lautstärke/Helligkeit ändern sich reaktiv, EGAL wodurch - Medientasten
    // (bindings.lua ruft wpctl/brightnessctl direkt auf, komplett an
    // quickshell vorbei), der Control-Center-Slider, oder von extern.
    // Audio/Brightness beobachten selbst den echten Systemzustand, kriegen
    // die Änderung so oder so mit - kein Bedarf für eine eigene IPC-Route
    // wie bei den View-Togglern.
    //
    // _audioSeeded/_brightnessSeeded unterdrücken jeweils GENAU die erste
    // Änderung: Audio.volume/muted starten mit einem Platzhalterwert
    // (0/true), bis der PipeWire-Sink getrackt ist (Audio.ready), ebenso
    // Brightness.percentage/available (Platzhalter 1.0, bis brightnessctl
    // beim Start einmal durchgelaufen ist) - dieser initiale Sprung auf den
    // ECHTEN Wert feuert onVolumeChanged/onPercentageChanged genau wie eine
    // echte Änderung, ist aber keine. Live beobachtet: ohne diese Guards
    // poppt beim Quickshell-Start (z.B. nach `systemctl restart
    // quickshell.service`) eine Phantom-Helligkeits-OSD auf, obwohl niemand
    // die Helligkeit angefasst hat.
    property bool _audioSeeded: false
    property bool _brightnessSeeded: false

    function _showAudio() {
        if (!root._audioSeeded) { root._audioSeeded = true; return }
        root._show("volume")
    }

    Connections {
        target: Audio
        function onVolumeChanged() { root._showAudio() }
        function onMutedChanged() { root._showAudio() }
    }

    Connections {
        target: Brightness
        function onPercentageChanged() {
            if (!root._brightnessSeeded) { root._brightnessSeeded = true; return }
            root._show("brightness")
        }
    }

    // Submap-OSD hat BEWUSST keinen Timer, anders als Lautstärke/Helligkeit
    // oben - sie soll exakt so lange sichtbar bleiben, wie die Submap
    // tatsächlich aktiv ist (verschwindet, sobald Hyprland den
    // "submap"-Reset-Event meldet), nicht nach einer festen Zeit
    // verschwinden, während man eigentlich noch drin ist.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "submap") return
            root.submapName = event.data
            if (event.data.length > 0) {
                hideTimer.stop()
                root.channel = "submap"
            } else if (root.channel === "submap") {
                root.channel = ""
            }
        }
    }
}
