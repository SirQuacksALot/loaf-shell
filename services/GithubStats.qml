pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Contribution-Heatmap-Daten für ControlCenterView (siehe
// widgets/GithubHeatmap.qml). GitHubs eigene API gibt Contribution-Zahlen
// nur über GraphQL + Personal-Access-Token raus - ohne `gh auth login` oder
// hinterlegtes Token bleibt nur ein inoffizieller Public-JSON-Endpoint
// (github-contributions-api.jogruber.de, kein Login nötig - scraped den
// öffentlichen Contribution-Graph). Gleiche Kategorie wie lrclib.net in
// Lyrics.qml: kostenloser Drittanbieter statt offizieller API.
//
// Username ist per Klick im Widget editierbar (siehe GithubHeatmap.qml)
// und wird lokal persistiert (Quickshell.dataPath), Contribution-Daten
// werden zusätzlich 24h gecacht, damit nicht bei jedem Insel-Öffnen neu
// geladen wird.
Singleton {
    id: root

    property string username: "SirQuacksALot"
    property var contributions: []   // [{date, count, level}, ...] - älteste zuerst
    property int totalCount: 0
    property bool loading: false

    // Treibt cacheFile.path (siehe unten) - erst gesetzt, wenn settingsFile
    // fertig geladen (oder fehlgeschlagen) ist, damit cacheFile nicht mit
    // dem Default-Namen lädt, bevor ein gespeicherter Username Chance hatte
    // sich durchzusetzen.
    property string _cacheKey: ""

    function setUsername(name) {
        const trimmed = (name || "").trim();
        if (trimmed.length === 0 || trimmed === root.username) return;
        root.username = trimmed;
        root._saveSettings();
        root._cacheKey = root.username;
    }

    function _saveSettings() {
        try {
            settingsFile.setText(JSON.stringify({ username: root.username }));
        } catch (e) {
            console.warn("GithubStats: Settings nicht gespeichert:", e);
        }
    }

    FileView {
        id: settingsFile
        path: Quickshell.dataPath("github-settings.json")
        preload: true
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(settingsFile.text());
                if (parsed.username) root.username = parsed.username;
            } catch (e) { /* Default-Username bleibt */ }
            root._cacheKey = root.username;
        }
        onLoadFailed: root._cacheKey = root.username
    }

    // WICHTIG: path als deklaratives Binding + preload:true - genau wie
    // settingsFile. Ein manuelles `cacheFile.path = ...; cacheFile.reload()`
    // (wie in Lyrics.qml) hat hier beobachtbar NIE onLoaded/onLoadFailed
    // ausgelöst (aus unklarem Grund, evtl. Timing-Eigenheit bei
    // preload:false + programmatischem Reload). Diese Variante ist live
    // gegen die echte API verifiziert.
    FileView {
        id: cacheFile
        path: root._cacheKey ? Quickshell.dataPath("github-contrib-" + root._cacheKey + ".json") : ""
        preload: true
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(cacheFile.text());
                root._applyData(data);
                const ageMs = Date.now() - (data._fetchedAt || 0);
                if (ageMs > 24 * 60 * 60 * 1000) root._fetchFromNetwork();
            } catch (e) {
                root._fetchFromNetwork();
            }
        }
        onLoadFailed: if (root._cacheKey) root._fetchFromNetwork()
    }

    function _fetchFromNetwork() {
        if (!root.username) return;
        root.loading = true;
        const user = root.username;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (user !== root.username) return; // Username wurde inzwischen geändert
            root.loading = false;
            if (xhr.status !== 200) return;
            try {
                const data = JSON.parse(xhr.responseText);
                data._fetchedAt = Date.now();
                root._applyData(data);
                root._saveCache(user, data);
            } catch (e) {
                console.warn("GithubStats: Antwort konnte nicht gelesen werden:", e);
            }
        };
        xhr.open("GET", "https://github-contributions-api.jogruber.de/v4/" + encodeURIComponent(user) + "?y=last");
        xhr.send();
    }

    function _applyData(data) {
        root.contributions = Array.isArray(data.contributions) ? data.contributions : [];
        let sum = 0;
        for (const c of root.contributions) sum += (c.count || 0);
        root.totalCount = sum;
    }

    function _saveCache(user, data) {
        try {
            cacheFile.path = Quickshell.dataPath("github-contrib-" + user + ".json");
            cacheFile.setText(JSON.stringify(data));
        } catch (e) {
            console.warn("GithubStats: Cache nicht geschrieben:", e);
        }
    }
}
