import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."
import "../.."
import "../../.."
import "../../../services" as Services

// Wallpaper-Auswahl als "Wahlscheibe": eine horizontale Reihe aus
// Querformat-Kacheln (kein Hochkant mehr - Wallpaper sind nun mal breiter
// als hoch). Die aktuell AUSGEWÄHLTE Kachel ist immer auch der aktive
// Wallpaper - Navigieren (Pfeiltasten/Klick) wendet nach kurzer Debounce
// automatisch an, wie ein Drehregler, kein separater "Anwenden"-Schritt
// mehr für lokale Dateien. Beim Öffnen synchronisiert sich die Auswahl
// automatisch auf den gerade aktiven Wallpaper zurück (siehe
// syncSelectionToActive). Die ausgewählte Kachel ist zusätzlich größer als
// die übrigen (selectedScale unten) - der eigentliche "Wahlscheiben"-Look.
//
// Online-Quellen (Wallhaven/Anime Gallery, siehe services/Wallpaper.qml)
// sind KEINE Tabs mehr, sondern zwei Einstiegs-Kacheln ganz am Ende des
// lokalen Wheels (kind: "action") - Enter/Tap darauf ersetzt den
// GESAMTEN Wheel-Inhalt durch Online-Ergebnisse dieser Quelle (inkl.
// eingeblendetem Suchfeld), ein "Zurück"-Eintrag ganz vorn in den
// Ergebnissen bringt zu den lokalen Wallpapern zurück. Dort bewusst KEIN
// Live-Apply beim bloßen Navigieren - jeder Wechsel würde einen Download
// auslösen, das wäre bei schnellem Durchblättern viel zu teuer. Enter/Tap
// bestätigt dort weiterhin einzeln (downloadAndApply), wie vorher.
MorphItem {
    id: view

    name: "wallpaper"
    preferredWidth: 480
    // Online-Modus braucht zusätzlich Platz fürs Suchfeld.
    preferredHeight: view.mode === "local" ? 150 : 200

    required property var islandRoot

    property string mode: "local"   // "local" | "wallhaven" | "anime"
    property string searchText: ""

    readonly property var localItems:
        Services.Wallpaper.files.map(p => ({ kind: "wallpaper", id: p, thumbUrl: "file://" + p, path: p, isRemote: false }))

    // Lokales Wheel = alle Dateien + zwei Einstiegs-Kacheln für die
    // Online-Quellen ganz am Ende.
    readonly property var localWheel: view.localItems.concat([
        { kind: "action", id: "__wallhaven", label: Localization.wallpaper.wallhaven, icon: "search", target: "wallhaven" },
        { kind: "action", id: "__anime", label: Localization.wallpaper.animeGallery, icon: "search", target: "anime" }
    ])

    // -1 für die "Zurück"-Kachel, die in resultsModel als erster Eintrag
    // immer mit drinsteckt (siehe _replaceResults) - zählt nicht als
    // Ergebnis fürs "Keine Ergebnisse". Math.max schützt vor dem kurzen
    // Zwischenzustand direkt nach resultsModel.clear(), bevor der erste
    // append() (der "Zurück"-Eintrag) wieder drin ist.
    readonly property int currentCount: view.mode === "local" ? view.localItems.length : Math.max(0, resultsModel.count - 1)

    function runSearch() {
        if (view.mode === "wallhaven") Services.Wallpaper.searchWallhaven(view.searchText);
        else if (view.mode === "anime") Services.Wallpaper.searchAnimeGallery(view.searchText);
    }

    // Vorlade-Quelle je nach Modus, siehe services/Wallpaper.qml.
    function loadMore() {
        if (view.mode === "wallhaven") Services.Wallpaper.loadMoreWallhaven();
        else if (view.mode === "anime") Services.Wallpaper.loadMoreAnimeGallery();
    }

    // Wechselt den GESAMTEN Wheel-Inhalt (ersetzt die frühere Tab-Logik) -
    // aufgerufen von den Einstiegs-/Zurück-Kacheln unten.
    function enterMode(target) {
        view.searchText = ""
        view.mode = target
        list.currentIndex = 0
        if (target !== "local") view.runSearch()
        else Services.Wallpaper.refresh()
    }

    // Synchronisiert die Wheel-Auswahl auf den gerade tatsächlich aktiven
    // Wallpaper - aufgerufen beim Öffnen der View (siehe onActiveChanged
    // unten), NICHT laufend/reaktiv gebunden (sonst Gefahr eines
    // Rückkopplungs-Zyklus mit applyDebounce unten, auch wenn der durch
    // den Vergleich auf denselben Wert an sich harmlos wäre - so ist die
    // Richtung "beim Öffnen von außen nach innen synchronisieren, beim
    // Navigieren von innen nach außen anwenden" eindeutig getrennt).
    function syncSelectionToActive() {
        const idx = view.localItems.findIndex(it => it.path === Services.Wallpaper.current)
        list.currentIndex = idx >= 0 ? idx : 0
    }

    function activateCurrent() {
        const item = view.mode === "local"
            ? view.localWheel[list.currentIndex]
            : (resultsModel.get(list.currentIndex) ? resultsModel.get(list.currentIndex).modelData : null)
        if (!item) return
        if (item.kind === "action") { view.enterMode(item.target); return }
        if (item.isRemote) Services.Wallpaper.downloadAndApply(item)
        // Lokale Wallpaper sind durchs bloße Navigieren bereits angewendet
        // (siehe applyDebounce) - Enter bestätigt hier nur nochmal
        // explizit/ohne die kurze Wartezeit.
        else Services.Wallpaper.apply(item.path)
    }

    // Kein sofortiges apply() bei JEDEM currentIndex-Wechsel - beim
    // schnellen Durchblättern (Pfeiltaste gedrückt halten) würde das den
    // Wallpaper-Compositor mit überlappenden, je 1s dauernden Übergängen
    // fluten (siehe Services.Wallpaper.apply()). Kurze Debounce statt
    // dessen, exakt dasselbe Muster wie searchDebounce unten für die
    // Online-Suche. Auf Root-Ebene statt in der ListView verschachtelt -
    // siehe BluetoothView.qml/scanTimer für die Begründung (sonst
    // ReferenceError, falls onCurrentIndexChanged vor der vollständigen
    // Konstruktion tief verschachtelter Objekte feuert).
    Timer {
        id: applyDebounce
        interval: 150
        onTriggered: {
            if (view.mode !== "local") return
            const item = view.localWheel[list.currentIndex]
            if (!item || item.kind !== "wallpaper") return
            Services.Wallpaper.apply(item.path)
        }
    }

    ListModel { id: resultsModel }

    function _toRow(item) {
        return { modelData: { kind: "wallpaper", id: item.id, thumbUrl: item.thumbUrl, fullUrl: item.fullUrl, source: item.source, isRemote: true } }
    }

    readonly property var backItem: ({ kind: "action", id: "__back", label: Localization.wallpaper.back, icon: "arrow-left", target: "local" })

    Connections {
        target: Services.Wallpaper
        function onWallhavenReset() { if (view.mode === "wallhaven") view._replaceResults(Services.Wallpaper.wallhavenResults) }
        function onWallhavenAppended(items) { if (view.mode === "wallhaven") view._appendResults(items) }
        function onAnimeReset() { if (view.mode === "anime") view._replaceResults(Services.Wallpaper.animeGalleryResults) }
        function onAnimeAppended(items) { if (view.mode === "anime") view._appendResults(items) }
    }

    // "Zurück"-Kachel wird IMMER als allererster Eintrag mit reingelegt -
    // dadurch kennt der Delegate unten keinen Sonderfall "Modell hat noch
    // keine Zurück-Kachel", sie ist strukturell immer da.
    function _replaceResults(items) {
        resultsModel.clear()
        resultsModel.append({ modelData: view.backItem })
        for (const it of items) resultsModel.append(view._toRow(it))
    }
    function _appendResults(items) {
        for (const it of items) resultsModel.append(view._toRow(it))
    }

    // 400ms nach der letzten Eingabe automatisch neu suchen - deckt auch
    // den Fall ab, dass das Feld komplett geleert wird (dann greift der
    // Zufalls-Modus in services/Wallpaper.qml), ohne bei jedem
    // Tastendruck sofort eine neue Anfrage abzufeuern.
    Timer {
        id: searchDebounce
        interval: 400
        onTriggered: view.runSearch()
    }

    // Holt sich Tastaturfokus, sobald diese View aktiv wird (siehe
    // AppLauncher.qml: onVisibleChanged -> forceActiveFocus() fürs
    // Suchfeld, gleiches Prinzip) - ohne das kämen Pfeiltasten/Enter nie
    // bei list an, PanelWindow-Fokus ist standardmäßig "OnDemand", nicht
    // automatisch bei irgendeinem Kind.
    onActiveChanged: {
        if (view.active) {
            list.forceActiveFocus()
            if (view.mode === "local") {
                Services.Wallpaper.refresh()
                view.syncSelectionToActive()
            } else {
                view.runSearch()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: view.mode !== "local"

            TextField {
                id: searchField
                Layout.fillWidth: true
                text: view.searchText
                placeholderText: Localization.wallpaper.searchPlaceholder
                color: Theme.colors.text
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 1
                background: Rectangle {
                    radius: 8
                    color: Theme.colors.surface
                    border.width: 1
                    border.color: Theme.colors.borderSurface
                }
                onTextChanged: { view.searchText = text; searchDebounce.restart() }
                onAccepted: { searchDebounce.stop(); view.runSearch() }
            }
            ActionButton {
                icon: "search"
                iconSize: 13
                diameter: 26
                tooltip: Localization.wallpaper.searchTooltip
                onTapped: { searchDebounce.stop(); view.runSearch() }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 16
            visible: view.mode !== "local" && Services.Wallpaper.searching
            text: Localization.wallpaper.searching
            horizontalAlignment: Text.AlignHCenter
            color: Theme.colors.textMuted
            font.family: Theme.font.family
            font.pixelSize: Theme.font.size - 2
        }
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 16
            // Leeres Suchfeld lädt automatisch eine Zufallsauswahl (siehe
            // enterMode/onAccepted oben) - dieser Text erscheint daher nur
            // noch, wenn eine gezielte Suche wirklich nichts gefunden hat.
            visible: view.mode !== "local" && !Services.Wallpaper.searching && view.currentCount === 0
            text: Localization.wallpaper.noResults
            horizontalAlignment: Text.AlignHCenter
            color: Theme.colors.textMuted
            font.family: Theme.font.family
            font.pixelSize: Theme.font.size - 2
        }

        // Wrapper statt WheelHandler direkt an list - Flickable (Basis von
        // ListView) fängt Wheel-Events selbst über einen tieferliegenden
        // C++-Mechanismus ab, EIN an list selbst hängender WheelHandler
        // bekam sie nie zu Gesicht (0 Treffer im Test-Log). Ein separates
        // Overlay-Item OBEN drauf (nach list deklariert = höherer Z-Wert)
        // sieht das Wheel-Event zuerst, bevor list überhaupt drankommt -
        // greift NUR Wheel ab (kein MouseArea/TapHandler drin), Klicks auf
        // die Kacheln darunter bleiben dadurch unangetastet.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: list
                // Kein anchors.fill mehr - die Liste bekommt nur so viel
                // Breite wie ihr Inhalt tatsächlich braucht (gedeckelt auf
                // die verfügbare Breite) und zentriert SICH SELBST im
                // Wrapper. Sonst blieb die Kachel-Reihe bei wenigen
                // Einträgen (die die volle Breite gar nicht ausfüllen)
                // sichtbar linksbündig hängen, statt mittig zu wirken.
                // Füllt der Inhalt die Breite tatsächlich aus, ist
                // width == parent.width - dann verhält sich das exakt wie
                // vorher (normales Scrollen).
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                height: parent.height
                width: Math.min(parent.width, list.contentWidth)
                clip: true
                orientation: ListView.Horizontal
                spacing: 8
                model: view.mode === "local" ? view.localWheel : resultsModel

                // Querformat statt der früheren, an der ganzen View-Höhe
                // orientierten (faktisch Hochkant-artigen) Kacheln - die
                // ausgewählte Kachel ist zusätzlich per selectedScale
                // größer, das ist der eigentliche "Wahlscheiben"-Effekt.
                // Kein fest berechnetes "genau 4 pro Reihe" mehr (ging bei
                // unterschiedlich großen Kacheln nicht mehr sauber auf) -
                // eine feste Basisbreite reicht, der Rest scrollt.
                readonly property int baseTileWidth: 130
                readonly property real tileAspect: 16 / 9
                readonly property real selectedScale: 1.3
                readonly property real selectedTileWidth: list.baseTileWidth * list.selectedScale

                // Echter "Wahlscheiben"-Effekt: die ausgewählte Kachel
                // bleibt beim Navigieren IMMER mittig im sichtbaren
                // Bereich, der Rest rutscht drumherum durch - statt nur
                // gerade so ins Bild zu ragen (ListView-Standard). Bewusst
                // ApplyRange statt StrictlyEnforceRange: Letzteres würde
                // auch das manuelle Wheel-Scrollen (siehe MouseArea unten)
                // ans Raster binden und sich dagegen sperren - ApplyRange
                // zentriert nur, WENN sich currentIndex ändert (Pfeiltasten/
                // Klick/Enter), freies Scrollen zum Stöbern bleibt
                // unangetastet möglich.
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: (list.width - list.selectedTileWidth) / 2
                preferredHighlightEnd: list.preferredHighlightBegin + list.selectedTileWidth

                highlightMoveDuration: 150
                Keys.onReturnPressed: view.activateCurrent()
                Keys.onEnterPressed: view.activateCurrent()

                // Escape geht im Online-Modus erst zurück zu den lokalen
                // Wallpapern, statt gleich die ganze View zu schließen -
                // MorphContainer.qml fängt Escape sonst global ab
                // (schließt die View, siehe IslandShape.onEscapePressed).
                // event.accepted hier verhindert genau das, SOLANGE man
                // noch nicht lokal ist.
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape && view.mode !== "local") {
                        view.enterMode("local")
                        event.accepted = true
                    } else {
                        // Explizit false statt weglassen - Qt Quick liefert
                        // accepted an JEDES Item mit Keys.onPressed-Handler
                        // sonst schon als true, egal ob der Handler-Body was
                        // tut. Ohne das hier würde z.B. Tab (sobald list den
                        // Fokus hat) NIE beim zentralen Handler in
                        // MorphContainer.qml ankommen - genau der Bug, der
                        // als "Tab-Navigation bricht nach dem ersten Druck
                        // ab" live beobachtet wurde (betraf denselben Fehler
                        // auch in MenuButton/ActionButton/Toggle, siehe dort).
                        event.accepted = false
                    }
                }

                onCurrentIndexChanged: {
                    // WICHTIG: view.active-Guard. Die View ist wie alle
                    // anderen NIE entladen (siehe IslandRoot.qml-Kommentar
                    // "immer voll geladen, kein Loader") - ihre ListView
                    // existiert also schon beim Quickshell-Start, lange bevor
                    // sie je geöffnet wird. Sobald Services.Wallpaper.files
                    // asynchron eintrudelt, bekommt list.model zum ersten Mal
                    // Einträge und currentIndex springt von -1 auf 0 - OHNE
                    // diesen Guard hätte das reflexartig applyDebounce
                    // losgetreten und den allerersten Wallpaper angewendet,
                    // noch bevor der Nutzer die View je geöffnet hat (der
                    // eigentliche Grund für "Wallpaper springt beim Hyprland-
                    // Start auf den ersten zurück", live verifiziert).
                    if (!view.active) return
                    if (view.mode === "local") applyDebounce.restart()
                    // Zählt als Aktivität fürs Hotkey-Hold/Auto-Close
                    // (Pfeiltasten, Klick, Mausrad - alles ändert
                    // currentIndex), siehe IslandRoot.noteActivity(). Ohne
                    // das würde reines Durchblättern per Tastatur (Maus
                    // rührt sich nicht) einfach abgewürgt.
                    view.islandRoot.noteActivity()
                }

                // Vorlade-Schwelle: eine ganze Seite der jeweiligen Quelle
                // (24 bei Wallhaven, 80 bei Anime Gallery) statt nur ein
                // paar Kacheln - lädt dadurch schon nach, während man noch
                // auf der VORLETZTEN Seite scrollt, nicht erst am
                // tatsächlichen Ende.
                readonly property real loadMoreMargin: (list.baseTileWidth + list.spacing) *
                    (view.mode === "wallhaven" ? Services.Wallpaper.wallhavenPerPage : Services.Wallpaper.animePerPage)

                // Infinite Scroll: sobald man sich der Vorlade-Schwelle
                // nähert (egal ob per Mauswheel oder Pfeiltasten - beide
                // ändern contentX), automatisch nachladen. loadMore() ist
                // in Services.Wallpaper selbst gegen Mehrfachaufrufe
                // abgesichert (wallhavenLoadingMore/animeLoadingMore).
                onContentXChanged: {
                    if (view.mode === "local") return
                    if (list.contentWidth - (list.contentX + list.width) < list.loadMoreMargin)
                        view.loadMore()
                }

                // Dezenter Spinner ganz am Ende der Reihe, während im
                // Hintergrund nachgeladen wird - ersetzt NICHT die
                // bestehenden Ergebnisse (anders als das große "Suche…"
                // beim ersten Laden), damit man beim Scrollen nicht ruckelt.
                footer: Item {
                    id: loadMoreFooter
                    readonly property bool loading: view.mode === "wallhaven"
                        ? Services.Wallpaper.wallhavenLoadingMore
                        : view.mode === "anime" ? Services.Wallpaper.animeLoadingMore : false
                    width: loading ? list.baseTileWidth : 0
                    height: list.height
                    visible: loading

                    LucideIcon {
                        anchors.centerIn: parent
                        name: "loader-circle"
                        size: 20
                        color: Theme.colors.textMuted

                        RotationAnimation on rotation {
                            running: loadMoreFooter.loading
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 800
                        }
                    }
                }

                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index

                    readonly property bool isSelected: tile.ListView.isCurrentItem
                    // visualWidth/-Height statt direkt width/height: die
                    // ÄUSSERE Kachel (tile selbst) braucht die volle
                    // list.height, weil ListView bei horizontaler
                    // Ausrichtung die y-Position jedes Delegates SELBST
                    // setzt (immer y=0) - eine eigene y-Bindung auf tile
                    // wird dabei von Qt Quick klammheimlich überschrieben,
                    // wirkungslos. `width` MUSS trotzdem visualWidth
                    // folgen (treibt den horizontalen Zeilenabstand -
                    // genau das, was die ausgewählte Kachel "breiter"
                    // macht). Die eigentliche, größenanimierte Fläche
                    // (frame unten) ist ein KIND von tile und per
                    // anchors.centerIn zentriert - das kann ListView
                    // nicht überschreiben, nur die Position des äußeren
                    // Delegates selbst.
                    readonly property real visualWidth: list.baseTileWidth * (tile.isSelected ? list.selectedScale : 1)
                    readonly property real visualHeight: tile.visualWidth / list.tileAspect
                    width: tile.visualWidth
                    height: list.height

                    Behavior on width { NumberAnimation { duration: Theme.animationDurations.normal; easing.type: Easing.OutCubic } }

                    readonly property bool active: tile.modelData.kind === "wallpaper" && !tile.modelData.isRemote && Services.Wallpaper.current === tile.modelData.path
                    readonly property bool downloading: tile.modelData.kind === "wallpaper" && tile.modelData.isRemote && Services.Wallpaper.downloadingId === tile.modelData.id

                    Rectangle {
                        id: frame
                        anchors.centerIn: parent
                        width: tile.visualWidth - 8
                        height: tile.visualHeight - 8

                        Behavior on width { NumberAnimation { duration: Theme.animationDurations.normal; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: Theme.animationDurations.normal; easing.type: Easing.OutCubic } }
                        // Weder einfaches "radius" noch die Pro-Ecke-
                        // Variante (topLeftRadius etc.) hat das Image-Kind
                        // hier tatsächlich rund zugeschnitten (live
                        // verifiziert, beides blieb ein Rechteck) - clip
                        // greift bei einem Image innerhalb eines Rectangle
                        // hier offenbar nicht zuverlässig, unabhängig von
                        // der Radius-Variante. Eckmasken (4 kleine Kreise
                        // in Theme.colors.surface, siehe unten) umgehen das
                        // Problem komplett, unabhängig davon WARUM clip
                        // nicht greift.
                        readonly property int r: 6
                        radius: r
                        antialiasing: true
                        // Theme.colors.background statt .surface - das ist
                        // die tatsächliche Hintergrundfarbe DIESER View
                        // (siehe MorphItem.surfaceColor-Default, hier nicht
                        // überschrieben), sichtbar in den Lücken zwischen
                        // den Kacheln. Die Eckmasken übernehmen frame.color
                        // 1:1, ein Mismatch dort fiel als Farbbruch an der
                        // gerundeten Ecke auf.
                        color: Theme.colors.background
                        clip: true

                        Image {
                            id: thumbImage
                            anchors.fill: parent
                            visible: tile.modelData.kind === "wallpaper"
                            source: tile.modelData.kind === "wallpaper" ? tile.modelData.thumbUrl : ""
                            asynchronous: true
                            // Grob heruntergerechnet statt in voller
                            // Auflösung geladen - manche Dateien hier sind
                            // mehrere MB groß, für ein ~100px-Thumbnail
                            // reicht das nicht annähernd aus.
                            sourceSize.width: 224
                            sourceSize.height: 160
                            fillMode: Image.PreserveAspectCrop
                            horizontalAlignment: Image.AlignHCenter
                            verticalAlignment: Image.AlignVCenter

                            // Fade statt hartem Pop-in - lokale Dateien
                            // sind teils mehrere MB groß (die volle Datei
                            // muss trotz asynchronous:true erst decodiert
                            // werden, bevor sourceSize greift), das dauert
                            // spürbar länger als bei den schon kleinen
                            // Online-Thumbnails und poppt ohne Übergang
                            // sichtbar rein statt "seamless" zu wirken.
                            opacity: thumbImage.status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: Theme.animationDurations.short } }
                        }

                        // --- Einstiegs-/Zurück-Kachel (Wallhaven/Anime
                        // Gallery/Zurück) - Icon + Label statt Vorschaubild.
                        ColumnLayout {
                            anchors.centerIn: parent
                            visible: tile.modelData.kind === "action"
                            spacing: 6

                            LucideIcon {
                                Layout.alignment: Qt.AlignHCenter
                                name: tile.modelData.kind === "action" ? tile.modelData.icon : "image"
                                size: 20
                                color: Theme.colors.textMuted
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.maximumWidth: frame.width - 12
                                text: tile.modelData.kind === "action" ? tile.modelData.label : ""
                                color: Theme.colors.textMuted
                                font.family: Theme.font.family
                                font.pixelSize: Theme.font.size - 3
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.Wrap
                            }
                        }

                        // Lade-Overlay während des Downloads eines Online-
                        // Ergebnisses.
                        Rectangle {
                            anchors.fill: parent
                            visible: tile.downloading
                            color: Theme.colors.background
                            opacity: 0.6

                            LucideIcon {
                                anchors.centerIn: parent
                                name: "loader-circle"
                                size: 20
                                color: Theme.colors.text

                                RotationAnimation on rotation {
                                    running: tile.downloading
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 800
                                }
                            }
                        }

                        // Eckmasken statt Clipping - offizieller, bestätigter
                        // Qt-Bug (QTBUG-9008): clip:true schneidet IMMER nur
                        // auf die rechteckige Bounding-Box zu, NIE auf die
                        // gerundete Form, unabhängig von radius-Variante
                        // oder Qt-Version. Offiziell empfohlener Fix wäre
                        // layer.enabled + OpacityMask (Shader-Effekt) - das
                        // vermeidet dieses Projekt aber bewusst (siehe
                        // LucideIcon.qml-Kommentar). SVG-Masken (rect minus
                        // circle, per SVG <mask>), derselbe bereits
                        // bewährte Rendering-Pfad wie LucideIcon.qml/die
                        // App-Icons, garantiert glatt.
                        Repeater {
                            model: [
                                { x: 0, y: 0, cx: 1, cy: 1 },
                                { x: 1, y: 0, cx: 0, cy: 1 },
                                { x: 0, y: 1, cx: 1, cy: 0 },
                                { x: 1, y: 1, cx: 0, cy: 0 }
                            ]
                            delegate: Image {
                                required property var modelData
                                width: frame.r
                                height: frame.r
                                x: modelData.x ? frame.width - width : 0
                                y: modelData.y ? frame.height - height : 0
                                smooth: true

                                // Kreis-Mittelpunkt liegt beim jeweils
                                // GEGENÜBERLIEGENDEN Eck-Punkt dieses R×R-
                                // Feldes (Richtung "zur Bild-Mitte hin") -
                                // genau der Punkt, um den eine echte Rundung
                                // ihren Bogen zentrieren würde.
                                readonly property real circleX: modelData.cx * frame.r
                                readonly property real circleY: modelData.cy * frame.r
                                readonly property string svg:
                                    '<svg xmlns="http://www.w3.org/2000/svg" width="' + frame.r + '" height="' + frame.r + '">' +
                                    '<mask id="m"><rect width="' + frame.r + '" height="' + frame.r + '" fill="white"/>' +
                                    '<circle cx="' + circleX + '" cy="' + circleY + '" r="' + frame.r + '" fill="black"/></mask>' +
                                    '<rect width="' + frame.r + '" height="' + frame.r + '" fill="' + frame.color + '" mask="url(#m)"/></svg>'
                                source: "data:image/svg+xml;utf8," + encodeURIComponent(svg)
                            }
                        }
                    }

                    HoverHandler { id: tileHover }
                    TapHandler {
                        enabled: !tile.downloading
                        onTapped: {
                            if (tile.modelData.kind === "action") {
                                view.enterMode(tile.modelData.target)
                            } else if (tile.modelData.isRemote) {
                                list.currentIndex = tile.index
                                Services.Wallpaper.downloadAndApply(tile.modelData)
                            } else {
                                // Setzt currentIndex -> applyDebounce
                                // übernimmt das tatsächliche Anwenden,
                                // siehe onCurrentIndexChanged oben.
                                list.currentIndex = tile.index
                            }
                        }
                    }

                    Rectangle {
                        visible: tileHover.hovered && !tile.active
                        anchors.fill: frame
                        radius: frame.r
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.colors.text
                        opacity: 0.4
                    }

                }
            }

            // Overlay - siehe Kommentar oben. MouseArea statt WheelHandler:
            // Qt änderte zwischen 6.3 und 6.7 das Default-Wheel-Verhalten
            // von ListView, ein separat deklarierter WheelHandler bekam
            // die Events dadurch nie zu Gesicht (0 Treffer im Test-Log,
            // mehrfach). MouseArea.onWheel ist der im Qt-Forum als
            // funktionierend bestätigte Weg. acceptedButtons: Qt.NoButton
            // sorgt dafür, dass NUR Wheel abgegriffen wird - normale Klicks
            // greift die MouseArea gar nicht erst, die gehen ungehindert an
            // die TapHandler der Kacheln darunter durch.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: event => {
                    list.contentX = Math.max(0, Math.min(
                        list.contentX - event.angleDelta.y,
                        Math.max(0, list.contentWidth - list.width)
                    ))
                }
            }
        }
    }
}
