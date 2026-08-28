pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Wallpaper-Auswahl fürs Control Center (siehe views/WallpaperView.qml).
// Kein eigener Daemon hier - awww-daemon läuft bereits unabhängig
// (systemweit gestartet, IPC-fähiges Wayland-Wallpaper-Tool), wir sprechen
// ihn nur per CLI an (`awww img`), genau wie ein manueller Aufruf das täte.
//
// Zusätzlich zu den lokalen Dateien zwei Online-Quellen zum Durchsuchen:
// Wallhaven (offizielle, keylose JSON-API für SFW-Suchen, siehe
// https://wallhaven.cc/help/api) und theanimegallery.com (KEINE offizielle
// API - die Seite ist serverseitig mit Next.js gerendert und bettet ihre
// Suchergebnisse als JSON in einen <script id="__NEXT_DATA__">-Block ein,
// den wir stattdessen auslesen; robots.txt der Seite erlaubt Crawling
// uneingeschränkt. Bricht, falls die Seite ihr Rendering grundlegend
// ändert - dann liefert searchAnimeGallery() einfach eine leere Liste.
Singleton {
    id: root

    readonly property string directory: "/home/sebastian/Wallpapers"

    // Von Wallhaven/AnimeGallery heruntergeladene Bilder landen hier drin
    // statt direkt im Wallpaper-Ordner (siehe downloadAndApply()) - bleiben
    // dadurch klar von den handverlesenen/lokal hinzugefügten getrennt.
    // listProc unten durchsucht trotzdem BEIDE Ebenen (maxdepth 2), sie
    // tauchen also ganz normal mit in der "Lokal"-Liste auf.
    readonly property string onlineSubdir: "Online"
    readonly property string onlineDirectory: root.directory + "/" + root.onlineSubdir

    // Absolute Pfade aller Bilder im Wallpaper-Ordner.
    property var files: []
    property string current: ""

    // Online-Suchergebnisse, jeweils normalisiert auf {id, thumbUrl, fullUrl}
    // - WallpaperView kennt nur dieses gemeinsame Format, keine
    // quellenspezifischen Felder.
    property var wallhavenResults: []
    property var animeGalleryResults: []
    property bool searching: false

    // Id des Ergebnisses, das gerade heruntergeladen wird (für den
    // Lade-Spinner in der Kachel) - leer, wenn nichts läuft.
    property string downloadingId: ""

    // Getrennt von den *Changed-Signalen der Result-Properties oben, weil
    // die View zwingend wissen muss, OB ein Update ein Reset (neue Suche/
    // Tab-Wechsel - Liste soll an den Anfang springen) oder ein Anhängen
    // (Infinite Scroll - Scroll-Position MUSS erhalten bleiben) war. Ließe
    // sich aus den Arrays selbst nicht zuverlässig unterscheiden.
    signal wallhavenReset()
    signal wallhavenAppended(var items)
    signal animeReset()
    signal animeAppended(var items)

    // --- Wallhaven-Pagination (echtes Infinite Scroll - die API liefert
    // page/last_page in meta) ---
    // Feste Seitengröße der Wallhaven-API (per_page-Parameter unten) - der
    // View dient das als Vorlade-Schwelle fürs Infinite Scroll (siehe
    // WallpaperView.qml: schon eine ganze Seite vor dem echten Ende
    // nachladen statt erst am letzten Pixel).
    readonly property int wallhavenPerPage: 24
    property string wallhavenQuery: ""      // "" = Zufalls-Modus (sorting=random)
    property int wallhavenPage: 1
    property string wallhavenSeed: ""       // hält den Zufalls-Modus über mehrere Seiten halbwegs stabil
    property bool wallhavenHasMore: true
    property bool wallhavenLoadingMore: false

    // --- AnimeGallery-"Pagination" (die Seite ignoriert ?page= komplett -
    // jede Suche liefert immer dieselben ~80 Treffer. Als Ersatz laden wir
    // im Zufalls-Modus (kein Suchbegriff) beim Nachladen einfach eine
    // weitere zufällige /category/<tag>-Seite dazu und hängen sie an) ---
    // Feste Größe einer /category/-Seite (siehe _fetchAnimeCategory) - selbe
    // Rolle wie wallhavenPerPage oben, nur für die Anime-Gallery-Quelle.
    readonly property int animePerPage: 80
    property string animeQuery: ""
    property bool animeHasMore: false
    property bool animeLoadingMore: false
    // Kleine, von Hand kuratierte Auswahl echter Kategorie-Slugs der Seite
    // (aus der Navigation der Startseite abgelesen) - genug Streuung für
    // "zeig mir irgendwas", ohne die Kategorie-Liste selbst live abfragen
    // zu müssen (es gibt dafür keinen eigenen Endpunkt).
    readonly property var animeCategories: [
        "wallpaper", "aesthetic", "cute", "anime", "manga", "cartoon",
        "naruto", "sasuke", "kakashi", "itachi", "gojo", "kaisen",
        "luffy", "zoro", "piece", "goku", "gundam", "bleach", "berserk",
        "haikyuu", "hunter", "evangelion", "demon", "slayer", "couple",
        "tokyo", "desktop", "mobile", "iphone", "android", "sailor"
    ]

    function _randomAnimeCategory() {
        return root.animeCategories[Math.floor(Math.random() * root.animeCategories.length)];
    }

    function refresh() {
        listProc.running = true;
    }

    function apply(path) {
        if (!path) return;
        // "grow" statt des Standard-"simple"-Fade: ein Kreis wächst von der
        // Bildschirmmitte aus über den ganzen Screen - deutlich sichtbarer
        // Effekt beim Wechsel, siehe `awww img --help` für alle Optionen.
        setProc.command = [
            "awww", "img", "-a", path,
            "--transition-type", "grow",
            "--transition-pos", "center",
            "--transition-duration", "1",
            "--transition-fps", "60"
        ];
        setProc.running = true;
        // Optimistisch sofort übernehmen statt auf awww zu warten - die
        // Live-Vorschau (Highlight in WallpaperView) soll sich sofort
        // anfühlen, nicht erst nach dem Transition-Ende des Daemons.
        root.current = path;
    }

    // query == "" -> Zufalls-Modus (sorting=random statt q=...), sonst
    // normale Suche. Beides paginiert über wallhavenPage/loadMoreWallhaven().
    function searchWallhaven(query) {
        root.wallhavenQuery = query || "";
        root.wallhavenPage = 1;
        // Zufalls-Seed neu würfeln bei jeder frischen Suche/jedem Tab-Öffnen
        // - sonst käme bei "kein Suchbegriff" immer wieder dieselbe Auswahl.
        root.wallhavenSeed = root.wallhavenQuery.length === 0
            ? Math.random().toString(36).slice(2, 8) : "";
        root.wallhavenHasMore = true;
        root.searching = true;
        root._fetchWallhavenPage(false);
    }

    function loadMoreWallhaven() {
        if (!root.wallhavenHasMore || root.wallhavenLoadingMore) return;
        root.wallhavenLoadingMore = true;
        root.wallhavenPage += 1;
        root._fetchWallhavenPage(true);
    }

    function _fetchWallhavenPage(append) {
        let url = "https://wallhaven.cc/api/v1/search?per_page=24&page=" + root.wallhavenPage;
        url += root.wallhavenQuery.length > 0
            ? "&q=" + encodeURIComponent(root.wallhavenQuery)
            : "&sorting=random&seed=" + root.wallhavenSeed;
        wallhavenProc.append = append;
        wallhavenProc.command = ["curl", "-s", "-A", "Mozilla/5.0", url];
        wallhavenProc.running = true;
    }

    // query == "" -> Zufalls-Modus: zufällige /category/<tag>-Seite statt
    // Suche. loadMoreAnimeGallery() hängt dann bei Bedarf weitere zufällige
    // Kategorien an - echte Pagination gibt's hier nicht (siehe Kommentar
    // oben bei animeHasMore), eine gezielte Suche liefert daher immer nur
    // ihren einen festen Treffer-Batch.
    function searchAnimeGallery(query) {
        root.animeQuery = query || "";
        root.animeGalleryResults = [];
        root.animeHasMore = root.animeQuery.length === 0;
        root.searching = true;
        if (root.animeQuery.length === 0) {
            root._fetchAnimeCategory(root._randomAnimeCategory(), false);
        } else {
            animeGalleryProc.append = false;
            animeGalleryProc.command = ["curl", "-s", "-A", "Mozilla/5.0",
                "https://theanimegallery.com/search/" + encodeURIComponent(root.animeQuery)];
            animeGalleryProc.running = true;
        }
    }

    function loadMoreAnimeGallery() {
        if (!root.animeHasMore || root.animeLoadingMore) return;
        root.animeLoadingMore = true;
        root._fetchAnimeCategory(root._randomAnimeCategory(), true);
    }

    function _fetchAnimeCategory(category, append) {
        animeGalleryProc.append = append;
        animeGalleryProc.command = ["curl", "-s", "-A", "Mozilla/5.0",
            "https://theanimegallery.com/category/" + encodeURIComponent(category)];
        animeGalleryProc.running = true;
    }

    // Lädt ein Online-Ergebnis in den lokalen Wallpaper-Ordner herunter und
    // wendet es danach an - landet damit automatisch auch dauerhaft in der
    // "Lokal"-Liste, kein Extra-Cache nötig.
    function downloadAndApply(result) {
        if (!result || root.downloadingId === result.id) return;
        root.downloadingId = result.id;
        const ext = (result.fullUrl.match(/\.(jpe?g|png|webp|gif)(?:\?|$)/i) || [, "jpg"])[1].toLowerCase();
        const dest = root.onlineDirectory + "/" + result.source + "-" + result.id + "." + ext;
        downloadProc.dest = dest;
        downloadProc.command = ["curl", "-sL", "-A", "Mozilla/5.0", result.fullUrl, "-o", dest];
        downloadProc.running = true;
    }

    // -L statt eines normalen find, weil ~/Wallpapers zu großen Teilen aus
    // Symlinks besteht (historisch gewachsen) - ohne -L würde -type f die
    // Symlinks selbst (Typ "l", nicht "f") ausschließen und praktisch
    // nichts finden. maxdepth 2 statt 1 erfasst neben der Wallpaper-Ebene
    // selbst auch genau eine Ebene tiefer - reicht für onlineDirectory
    // (.../Online), ohne dass die Liste hier explizit von dessen Existenz
    // wissen müsste.
    //
    // -exec readlink -f {} \; statt find den rohen (Symlink-)Pfad
    // ausgeben zu lassen: awww löst Symlinks intern auf und meldet in
    // `awww query` den KANONISCHEN Pfad zurück (z.B. das tuckr-verwaltete
    // .config/dotfiles/.../Wallpapers/... hinter dem Symlink, live
    // verifiziert), nicht /home/sebastian/Wallpapers/... - ein reiner
    // String-Vergleich mit root.current (siehe syncSelectionToActive() in
    // WallpaperView.qml) schlug dadurch für jeden verlinkten Wallpaper
    // fehl, syncSelectionToActive() fiel auf Index 0 zurück und apply()
    // überschrieb den tatsächlich aktiven Wallpaper beim Öffnen der View
    // klammheimlich mit dem allerersten - genau der gemeldete "Wallpaper
    // wird beim Start immer auf den ersten gesetzt"-Bug. Kanonisieren wir
    // hier stattdessen selbst, matcht apply()/root.current 1:1 mit dem,
    // was awww query zurückgibt - unabhängig von Symlinks.
    Process {
        id: listProc
        command: ["find", "-L", root.directory, "-maxdepth", "2", "-type", "f",
            "-iregex", ".*\\.\\(png\\|jpe?g\\|webp\\|gif\\)$",
            "-exec", "readlink", "-f", "{}", ";"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = this.text.trim().length > 0 ? this.text.trim().split("\n") : [];
                // Nur bei tatsächlicher Änderung neu zuweisen: root.files
                // ist ein Singleton-Property, WallpaperView.localWheel läuft
                // in JEDEM IslandRoot (= pro Bildschirm) mit. Eine neue
                // Array-IDENTITÄT hier reißt bei allen Screens gleichzeitig
                // die komplette Kachel-ListView neu auf (jede Kachel
                // erzeugt wiederum 2 LucideIcons/FileViews), selbst wenn
                // sich am Inhalt nichts geändert hat. refresh() wird aber
                // bei jedem View-Öffnen aufgerufen - meist ohne dass sich
                // der Ordner seit dem letzten Mal geändert hat. Dieser
                // Massen-Reincubation-Sturm auf mehreren Screens gleichzeitig
                // hat live mehrfach den QML-Incubator abstürzen lassen
                // (SIGSEGV in VariantAssociationPrototype::fromQVariantMap,
                // siehe Crash-Reports) - ein reiner Inhaltsvergleich vorher
                // vermeidet die unnötigen Fälle davon.
                const changed = list.length !== root.files.length
                    || list.some((p, i) => p !== root.files[i]);
                if (changed) root.files = list;
            }
        }
    }

    // Stellt sicher, dass es den Unterordner für Online-Downloads gibt,
    // bevor der erste Download reinschreiben will (curl -o schlägt sonst
    // fehl, wenn das Zielverzeichnis noch nicht existiert).
    Process {
        id: mkdirOnlineProc
        command: ["mkdir", "-p", root.onlineDirectory]
    }

    // Aktuell gesetztes Wallpaper beim Start abfragen, statt bei "nichts
    // ausgewählt" zu starten - awww kennt den Zustand bereits (übersteht
    // ja auch einen Quickshell-Neustart).
    Process {
        id: queryProc
        command: ["awww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = this.text.match(/image: (\S+)/);
                if (match) root.current = match[1];
            }
        }
    }

    Process {
        id: setProc
    }

    Process {
        id: wallhavenProc
        // true, während des Nachladens (loadMoreWallhaven) an bestehende
        // Ergebnisse anhängen statt sie zu ersetzen.
        property bool append: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.searching = false;
                root.wallhavenLoadingMore = false;
                try {
                    const parsed = JSON.parse(this.text);
                    const meta = parsed.meta || {};
                    root.wallhavenHasMore = meta.current_page === undefined
                        || meta.current_page < meta.last_page;
                    const mapped = (parsed.data || []).map(w => ({
                        id: w.id,
                        thumbUrl: w.thumbs.small,
                        fullUrl: w.path,
                        source: "wallhaven"
                    }));
                    if (wallhavenProc.append) {
                        const known = new Set(root.wallhavenResults.map(r => r.id));
                        const fresh = mapped.filter(m => !known.has(m.id));
                        root.wallhavenResults = root.wallhavenResults.concat(fresh);
                        root.wallhavenAppended(fresh);
                    } else {
                        root.wallhavenResults = mapped;
                        root.wallhavenReset();
                    }
                } catch (e) {
                    console.warn("Wallpaper: Wallhaven-Antwort konnte nicht gelesen werden:", e);
                    if (!wallhavenProc.append) { root.wallhavenResults = []; root.wallhavenReset(); }
                }
            }
        }
    }

    Process {
        id: animeGalleryProc
        property bool append: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.searching = false;
                root.animeLoadingMore = false;
                try {
                    // [^>]* statt eines festen Attribut-Strings - manche
                    // Seiten der Domain (z.B. /category/...) haben ein
                    // zusätzliches crossorigin=""-Attribut am Script-Tag,
                    // das der vorherige starre Regex nicht erfasste und
                    // dort still leere Ergebnisse lieferte.
                    const match = this.text.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
                    const images = match ? (JSON.parse(match[1]).props.pageProps.images || []) : [];
                    const mapped = images.map(im => {
                        // Kleinste Variante aus dem srcset als Thumbnail -
                        // imageURL selbst ist die volle Auflösung, fürs
                        // Grid unnötig groß.
                        const first = (im.srcset || "").split(",")[0].trim().split(" ")[0];
                        return {
                            id: im.id,
                            thumbUrl: first || im.imageURL,
                            fullUrl: im.imageURL,
                            source: "animegallery"
                        };
                    });
                    if (animeGalleryProc.append) {
                        const known = new Set(root.animeGalleryResults.map(r => r.id));
                        const fresh = mapped.filter(m => !known.has(m.id));
                        root.animeGalleryResults = root.animeGalleryResults.concat(fresh);
                        root.animeAppended(fresh);
                    } else {
                        root.animeGalleryResults = mapped;
                        root.animeReset();
                    }
                } catch (e) {
                    console.warn("Wallpaper: AnimeGallery-Antwort konnte nicht gelesen werden (Seitenstruktur geändert?):", e);
                    if (!animeGalleryProc.append) { root.animeGalleryResults = []; root.animeReset(); }
                }
            }
        }
    }

    Process {
        id: downloadProc
        property string dest: ""
        onExited: exitCode => {
            if (exitCode === 0) {
                root.refresh();
                root.apply(downloadProc.dest);
            } else {
                console.warn("Wallpaper: Download fehlgeschlagen:", downloadProc.dest);
            }
            root.downloadingId = "";
        }
    }

    Component.onCompleted: {
        mkdirOnlineProc.running = true;
        root.refresh();
        queryProc.running = true;
    }
}
