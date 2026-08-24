pragma Singleton
import Quickshell
import Quickshell.Io

// Persistiert eine Liste angepinnter Desktop-Entry-IDs (z.B. "firefox",
// "org.gnome.Nautilus"). Wird sowohl vom AppLauncher (Stern zum Pinnen)
// als auch vom Dock (Anzeige der Quick-Launch-Icons) verwendet.
Singleton {
    id: root

    property var ids: []

    // Wird erst true, sobald der Ladeversuch abgeschlossen ist (egal ob
    // erfolgreich, leer oder Datei fehlt) - Windows.qml wartet damit, bis
    // die ECHTEN Favoriten da sind, bevor es dockEntries berechnet. Ohne
    // das: laufende, eigentlich angepinnte Apps zeigten sich kurz als
    // "nur laufend" (Favorites.ids noch []), wurden dann Sekunden später
    // in die andere Gruppe umsortiert - sah aus wie spontanes Verschwinden.
    property bool loaded: false

    function isFavorite(id) {
        return root.ids.indexOf(id) !== -1;
    }

    function toggle(id) {
        if (!id) return;
        const current = root.ids.slice();
        const idx = current.indexOf(id);
        if (idx === -1) {
            current.push(id);
        } else {
            current.splice(idx, 1);
        }
        root.ids = current;
        save();
    }

    // Umsortieren (Drag im Dock, siehe AppsView.qml) - newIndex ist die
    // Zielposition NACH dem Entfernen aus der alten Position.
    function moveToIndex(id, newIndex) {
        const current = root.ids.slice();
        const oldIndex = current.indexOf(id);
        if (oldIndex === -1) return;
        current.splice(oldIndex, 1);
        const clamped = Math.max(0, Math.min(newIndex, current.length));
        current.splice(clamped, 0, id);
        root.ids = current;
        save();
    }

    function save() {
        try {
            file.setText(JSON.stringify(root.ids));
        } catch (e) {
            console.warn("Favorites: konnte nicht speichern:", e);
        }
    }

    FileView {
        id: file
        path: Quickshell.dataPath("favorites.json")
        preload: true
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(file.text());
                if (Array.isArray(parsed)) root.ids = parsed;
            } catch (e) {
                root.ids = [];
            }
            root.loaded = true;
        }
        // Erster Start, noch keine favorites.json vorhanden - zählt auch
        // als "fertig geladen" (mit leeren ids, die stimmen dann einfach).
        onLoadFailed: root.loaded = true
    }
}
