pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Zeitsynchronisierte Songtexte für den aktuell in Mpris.qml laufenden
// Track, geladen von lrclib.net (kostenlos, kein API-Key nötig) und lokal
// unter ~/.local/share/quickshell/ gecacht, damit derselbe Song nicht bei
// jedem Play erneut abgefragt wird.
//
// Referenziert Mpris direkt beim Namen - beide Dateien liegen im selben
// Verzeichnis (services/), QML macht Typen aus demselben Ordner ohne
// Import sichtbar (siehe auch Windows.qml -> Favorites).
Singleton {
    id: root

    property var lines: []          // [{ time: <Sekunden>, text: <string> }, ...]
    property bool hasLyrics: false
    property bool loading: false
    property string plainText: ""   // Fallback, falls lrclib nur unsynced Lyrics hat

    readonly property int currentIndex: {
        if (!root.hasLyrics || root.lines.length === 0) return -1;
        const pos = Mpris.smoothPosition;
        let idx = -1;
        for (let i = 0; i < root.lines.length; i++) {
            if (root.lines[i].time <= pos) idx = i; else break;
        }
        return idx;
    }

    readonly property string currentLine: root.currentIndex >= 0 ? root.lines[root.currentIndex].text : ""
    readonly property string nextLine: (root.currentIndex + 1 < root.lines.length) ? root.lines[root.currentIndex + 1].text : ""

    property string _trackKey: ""

    function _keyFor(title, artist, album) {
        return Qt.md5(title + "|" + artist + "|" + album);
    }

    function _reset() {
        root.lines = [];
        root.plainText = "";
        root.hasLyrics = false;
        root.loading = false;
    }

    function _onTrackChanged() {
        if (!Mpris.available || Mpris.title === "") {
            root._trackKey = "";
            root._reset();
            return;
        }
        const key = root._keyFor(Mpris.title, Mpris.artist, Mpris.album);
        if (key === root._trackKey) return;
        root._trackKey = key;
        root._reset();
        root.loading = true;
        cacheFile.path = Quickshell.dataPath("lyrics-" + key + ".json");
        cacheFile.reload();
    }

    Connections {
        target: Mpris
        function onTitleChanged() { root._onTrackChanged() }
        function onArtistChanged() { root._onTrackChanged() }
    }

    FileView {
        id: cacheFile
        preload: false
        printErrors: false
        onLoaded: {
            try {
                root._applyLyrics(JSON.parse(cacheFile.text()));
                root.loading = false;
            } catch (e) {
                root._fetchFromNetwork();
            }
        }
        onLoadFailed: root._fetchFromNetwork()
    }

    function _fetchFromNetwork() {
        if (!Mpris.available) { root.loading = false; return; }

        const key = root._trackKey;
        const params = "track_name=" + encodeURIComponent(Mpris.title)
            + "&artist_name=" + encodeURIComponent(Mpris.artist)
            + (Mpris.album ? "&album_name=" + encodeURIComponent(Mpris.album) : "")
            + (Mpris.length > 0 ? "&duration=" + Math.round(Mpris.length) : "");

        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (key !== root._trackKey) return; // Track wurde inzwischen gewechselt
            root.loading = false;
            if (xhr.status !== 200) { root._reset(); return; }
            try {
                const data = JSON.parse(xhr.responseText);
                root._applyLyrics(data);
                root._saveToCache(key, data);
            } catch (e) {
                root._reset();
            }
        };
        xhr.open("GET", "https://lrclib.net/api/get?" + params);
        xhr.send();
    }

    function _applyLyrics(data) {
        if (data.syncedLyrics) {
            root.lines = root._parseLrc(data.syncedLyrics);
            root.hasLyrics = root.lines.length > 0;
        } else if (data.plainLyrics) {
            root.plainText = data.plainLyrics;
            root.lines = [];
            root.hasLyrics = false;
        } else {
            root._reset();
        }
    }

    function _parseLrc(text) {
        const out = [];
        const re = /\[(\d{2}):(\d{2}(?:\.\d+)?)\]/g;
        for (const rawLine of text.split("\n")) {
            const times = [];
            let match;
            let lastIndex = 0;
            re.lastIndex = 0;
            while ((match = re.exec(rawLine)) !== null) {
                times.push(parseInt(match[1], 10) * 60 + parseFloat(match[2]));
                lastIndex = re.lastIndex;
            }
            const content = rawLine.slice(lastIndex).trim();
            for (const t of times) out.push({ time: t, text: content });
        }
        out.sort((a, b) => a.time - b.time);
        return out;
    }

    function _saveToCache(key, data) {
        try {
            cacheFile.path = Quickshell.dataPath("lyrics-" + key + ".json");
            cacheFile.setText(JSON.stringify(data));
        } catch (e) {
            console.warn("Lyrics: Cache konnte nicht geschrieben werden:", e);
        }
    }
}
