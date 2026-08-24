pragma Singleton
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool available: device !== null && device.ready && device.isLaptopBattery
    readonly property real percentage: available ? device.percentage : 0
    readonly property bool charging: available && device.state === UPowerDeviceState.Charging
    readonly property bool fullyCharged: available && device.state === UPowerDeviceState.FullyCharged

    // Sekunden bis leer/voll - je nach Ladezustand ist immer nur eines der
    // beiden > 0 (UPower setzt das jeweils andere auf 0), siehe
    // BatteryIndicator.qml/InfoView.qml für die Tooltip-Anzeige.
    readonly property real timeToEmpty: available ? device.timeToEmpty : 0
    readonly property real timeToFull: available ? device.timeToFull : 0

    // "3h 12min" / "45min" - 0/negativ (UPower liefert das, solange die
    // Restzeit noch nicht verlässlich geschätzt werden kann, z.B. kurz
    // nach dem Einstecken) ergibt "" statt eines irreführenden "0min".
    function formatDuration(seconds) {
        if (!seconds || seconds <= 0) return "";
        const total = Math.round(seconds / 60);
        const h = Math.floor(total / 60);
        const m = total % 60;
        return h > 0 ? (h + "h " + m + "min") : (m + "min");
    }
}
