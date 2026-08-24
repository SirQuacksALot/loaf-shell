pragma Singleton
import Quickshell
import Quickshell.Bluetooth

// Wrapper um Quickshells eingebauten Bluez-Client. Steuert den Standard-
// Adapter (An/Aus, Discovery) und stellt die Geräteliste (gekoppelt +
// gefunden) für BluetoothView bereit. Pairing/Verbinden/Trennen/Vergessen
// läuft direkt über die jeweiligen BluetoothDevice-Objekte aus dieser
// Liste (device.pair()/connect()/disconnect()/forget()).
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled
    readonly property bool discovering: available && adapter.discovering

    // Alle bekannten Geräte dieses Adapters, gekoppelte zuerst, danach
    // nach Name sortiert - BlueZ liefert auch ungekoppelte, gerade beim
    // Scannen gefundene Geräte über dieselbe Liste.
    readonly property var devices: {
        if (!root.available) return [];
        const list = [...root.adapter.devices.values];
        list.sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            return (a.name || "").localeCompare(b.name || "");
        });
        return list;
    }

    readonly property var connectedDevices: root.devices.filter(d => d.connected)

    readonly property string iconName: {
        if (!available || !enabled) return "bluetooth-off";
        if (root.discovering) return "bluetooth-searching";
        return connectedDevices.length > 0 ? "bluetooth-connected" : "bluetooth";
    }

    readonly property string label: {
        if (!available) return "nicht verfügbar";
        if (!enabled) return "Aus";
        if (connectedDevices.length === 0) return "Ein";
        return connectedDevices.map(d => d.name).join(", ");
    }

    function toggle() {
        if (!available) return;
        adapter.enabled = !adapter.enabled;
    }

    function setDiscovering(on) {
        if (!available || !adapter.enabled) return;
        adapter.discovering = on;
    }

    // BlueZ liefert im "icon"-Property einen freedesktop-Icon-Hint (z.B.
    // "audio-headset", "input-mouse") - kein Lucide-Name. Grobe Zuordnung
    // per Substring statt vollständiger Freedesktop-Icon-Namen-Liste,
    // reicht für die üblichen Gerätetypen.
    function iconFor(device) {
        const hint = (device && device.icon) ? device.icon.toLowerCase() : "";
        if (hint.includes("headset") || hint.includes("headphone")) return "headphones";
        if (hint.includes("audio") || hint.includes("speaker")) return "speaker";
        if (hint.includes("mouse")) return "mouse";
        if (hint.includes("keyboard")) return "keyboard";
        if (hint.includes("phone")) return "smartphone";
        if (hint.includes("watch")) return "watch";
        if (hint.includes("printer")) return "printer";
        if (hint.includes("gaming") || hint.includes("joystick") || hint.includes("gamepad")) return "gamepad-2";
        if (hint.includes("tablet")) return "tablet";
        if (hint.includes("computer") || hint.includes("laptop")) return "monitor-smartphone";
        return "bluetooth";
    }
}
