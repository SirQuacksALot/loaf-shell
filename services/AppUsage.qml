pragma Singleton
import Quickshell
import Quickshell.Io

// Zentrale Nutzungszähler-Verwaltung - vorher steckte das (usageCounts,
// recordLaunch) lokal nur im AppLauncher, das Dock konnte davon nichts
// mitbekommen. Jetzt ein eigener Service wie Favorites/Windows, damit
// BEIDE (Launcher-Start UND Dock-Klick/Aktivieren, siehe Windows.qml)
// denselben Zähler füttern - AppLauncher sortiert weiterhin danach.
// Persistiert weiterhin unter derselben app-usage.json wie vorher.
Singleton {
    id: root

    property var counts: ({})

    function count(name) {
        return root.counts[name] || 0;
    }

    function record(name) {
        if (!name) return;
        const current = Object.assign({}, root.counts);
        current[name] = (current[name] || 0) + 1;
        root.counts = current;
        save();
    }

    function save() {
        try {
            file.setText(JSON.stringify(root.counts));
        } catch (e) {
            console.warn("AppUsage: konnte nicht speichern:", e);
        }
    }

    FileView {
        id: file
        path: Quickshell.dataPath("app-usage.json")
        preload: true
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(file.text());
                root.counts = (parsed && typeof parsed === "object") ? parsed : {};
            } catch (e) {
                root.counts = {};
            }
        }
        onLoadFailed: root.counts = {}
    }
}
