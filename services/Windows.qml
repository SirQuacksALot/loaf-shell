pragma Singleton
import Quickshell
import Quickshell.Wayland

// Verbindet ToplevelManager (zwlr-foreign-toplevel-management-v1 - läuft
// unter Hyprland genau wie unter anderen wlroots-Compositors) mit den
// gepinnten Favoriten aus Favorites.qml zu einer einzigen Dock-Liste.
//
// Jeder Eintrag in dockEntries:
//   { key, name, icon, desktopEntry, toplevels: [Toplevel...], pinned }
//
// - pinned && toplevels.length == 0  -> Favorit, nicht gestartet
// - toplevels.length > 0             -> läuft (ggf. mehrere Instanzen/Fenster)
// - beides gleichzeitig möglich      -> EIN Icon, wie gewünscht
Singleton {
    id: root

    function resolveEntry(appId) {
        if (!appId) return null;
        const direct = DesktopEntries.heuristicLookup(appId);
        if (direct) return direct;

        // Fallback für Apps, deren Wayland-appId nicht zur .desktop-Id
        // passt - z.B. meldet Obsidian sich als "md.obsidian.Obsidian"
        // (Reverse-DNS, gemischte Groß-/Kleinschreibung), während die
        // Desktop-Datei "obsidian" heißt. heuristicLookup matcht das
        // nicht (case-sensitiv). Erst case-insensitiv den ganzen String
        // versuchen, dann nur die letzte Punkt-Komponente.
        const lowerFull = appId.toLowerCase();
        const lowerLast = appId.split(".").pop().toLowerCase();
        const apps = DesktopEntries.applications.values;
        for (const app of apps) {
            const id = (app.id || "").toLowerCase();
            if (id === lowerFull || id === lowerLast) return app;
        }
        return null;
    }

    readonly property var dockEntries: {
        // Wartet auf Favorites.loaded - sonst würden laufende, eigentlich
        // angepinnte Apps kurz als "nur laufend" auftauchen und Sekunden
        // später (sobald favorites.json fertig geladen ist) in die
        // pinned-Gruppe umsortiert werden: alte Kachel weg, neue da - sah
        // aus wie spontanes Verschwinden. Lieber einmal leer starten, bis
        // die echten Daten da sind, statt zweimal (falsch, dann richtig).
        if (!Favorites.loaded) return [];

        const entries = {};
        const order = [];

        function ensure(key, fallbackName, fallbackIcon, entry) {
            if (!entries[key]) {
                entries[key] = {
                    key: key,
                    name: entry ? entry.name : fallbackName,
                    icon: entry ? entry.icon : fallbackIcon,
                    desktopEntry: entry || null,
                    toplevels: [],
                    pinned: false
                };
                order.push(key);
            }
            return entries[key];
        }

        // 1) Favoriten zuerst, damit die Reihenfolge im Dock stabil bleibt
        for (const id of Favorites.ids) {
            const entry = DesktopEntries.byId(id);
            if (!entry) continue;
            const e = ensure(entry.id, entry.name, entry.icon, entry);
            e.pinned = true;
        }

        // 2) Laufende Fenster einsortieren/mergen
        const toplevels = ToplevelManager.toplevels.values;
        for (const t of toplevels) {
            const entry = root.resolveEntry(t.appId);
            const key = entry ? entry.id : ("appid:" + t.appId);
            const e = ensure(key, t.appId, "", entry);
            e.toplevels.push(t);
        }

        return order.map(k => entries[k]);
    }

    // Fürs Dock in zwei sichtbar getrennte Gruppen aufgeteilt (siehe
    // AppsView.qml: Trennlinie dazwischen, nur wenn beide nicht leer
    // sind) - Angepinnte zuerst (ob laufend oder nicht), danach laufende,
    // nicht angepinnte Apps. dockEntries selbst bleibt die flache Liste
    // für alles, was nur "alle Einträge" braucht (z.B. den Trenner vorm
    // Launcher-Icon).
    readonly property var pinnedEntries: root.dockEntries.filter(e => e.pinned)
    readonly property var unpinnedRunningEntries: root.dockEntries.filter(e => !e.pinned)

    // Aktiviert eine Instanz oder wechselt zur nächsten, wenn die aktuell
    // aktive App bereits aktiviert ist (Cycling durch mehrere Fenster).
    function activateOrCycle(entry) {
        if (!entry.toplevels || entry.toplevels.length === 0) return;
        // Zählt für die Nutzungssortierung im AppLauncher mit (siehe
        // AppUsage.qml) - vorher fütterte NUR ein Start aus dem Launcher
        // selbst diesen Zähler, ein Dock-Klick (meistens: zu einer bereits
        // laufenden App wechseln) blieb unsichtbar für die Sortierung.
        AppUsage.record(entry.desktopEntry ? entry.desktopEntry.name : entry.name);
        if (entry.toplevels.length === 1) {
            entry.toplevels[0].activate();
            return;
        }
        const activeIdx = entry.toplevels.findIndex(t => t.activated);
        const nextIdx = (activeIdx + 1) % entry.toplevels.length;
        entry.toplevels[nextIdx].activate();
    }

    function launch(entry) {
        if (entry.desktopEntry) {
            entry.desktopEntry.execute();
            AppUsage.record(entry.desktopEntry.name);
        }
    }

    // Klickverhalten fürs Dock: läuft es? aktivieren/cyclen. sonst starten.
    function handleClick(entry) {
        if (entry.toplevels.length > 0) {
            activateOrCycle(entry);
        } else {
            launch(entry);
        }
    }

    // Anheften/Lösen - Kontextmenü-Aktion in Dock UND AppLauncher. Ohne
    // aufgelöstes DesktopEntry (reine appId-Fenster ohne .desktop-Datei)
    // gibt es nichts Stabiles zum Merken, also kein Pin möglich.
    function togglePin(entry) {
        if (entry.desktopEntry) Favorites.toggle(entry.desktopEntry.id);
    }

    // Schließt ALLE Fenster dieses Eintrags (ein Dock-Icon kann mehrere
    // Instanzen bündeln) - passend zu "Schließen" als EINE Kontextmenü-
    // Aktion fürs ganze Icon statt pro Fenster.
    function closeEntry(entry) {
        for (const t of entry.toplevels) t.close();
    }
}
