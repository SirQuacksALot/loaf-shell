import QtQuick
import ".."

// Ursprünglich nur für die Dynamic Island gebaut (siehe modules/island/),
// mittlerweile allgemein hier abgelegt, weil Dock.qml/AppsView.qml
// dasselbe Problem haben: Peek-Sliver <-> volle Inhalts-Fläche, dieselbe
// Feder-Choreographie. `edge` (Standard "top") sagt, an welcher
// Bildschirmkante der Container angedockt ist - bestimmt, welche Ecken im
// angedockten Zustand eckig bleiben und in welche Richtung "floating"
// von der Kante wegrutscht (Insel: oben angedockt, Dock: unten).
//
// Der Morph-Container IST die sichtbare Fläche selbst (siehe `surface`
// weiter unten) - kein unsichtbarer Rahmen um mehrere unabhängig
// gezeichnete Pillen. Genau das ist der Unterschied zwischen echtem
// "Flächen-Resizing" (hier) und "eine Pille verschwindet, eine andere
// taucht später an derselben Stelle auf" (frühere Version dieser Datei):
// die Fläche bleibt während des GESAMTEN Übergangs durchgehend sichtbar
// und ändert in Echtzeit ihre Größe - nur der INHALT (die Kinder der
// jeweils aktiven MorphItem, siehe MorphItem.qml) blendet kurz aus/ein.
//
// `target` bestimmt den gewünschten Zustand (muss zum `name` eines
// MorphItem-Kindes passen). Ablauf bei jeder Änderung von target:
//   1) alle nicht mehr passenden Items werden sofort deaktiviert ->
//      blenden über ihre EIGENE Transition aus (siehe MorphItem.qml)
//   2) die Fläche selbst morpht (weiterhin sichtbar!) auf die Maße des
//      neuen Ziel-Items (SpringAnimation on width/height)
//   3) das neue Ziel-Item wird erst aktiviert, wenn BEIDES tatsächlich
//      abgeschlossen ist: die Leave-Dauer ist um UND width/height sind
//      wirklich fertig eingeschwungen (nicht nur "vermutlich, nach X ms")
//      - siehe widthAnim/heightAnim + _tryActivate() unten.
//
// Root ist ein einfaches Item statt direkt ein Rectangle - der Schatten
// (siehe ShadowLayer unten) muss als GESCHWISTER von `surface` liegen,
// nicht als dessen Kind (surface hat `clip: true`, ein Kind, das über
// surfaces eigene Grenzen hinausragt, würde sonst weggeschnitten). Für
// Aufrufer ändert sich nichts - `target`/`maxContentWidth`/`floatingGap`/
// Kinder-Default landen weiterhin direkt auf diesem Root-Item.
Item {
    id: root

    property string target: ""
    property int leaveDuration: Config.leaveDuration

    // Escape gedrückt, während irgendein Kind-Button hier drin fokussiert
    // war - MorphContainer kennt "schließen" nicht selbst (das ist
    // IslandRoot/Dock-spezifisch, siehe closeView()), gibt es deshalb nur
    // als Signal nach außen weiter.
    signal escapePressed()

    // Tab/Umschalt+Tab wandert durch alle Kind-Items mit
    // activeFocusOnTab:true (ActionButton/MenuButton/Toggle setzen das
    // automatisch, siehe dort) - EIN zentraler Handler hier reicht für
    // Dock UND Island, statt jeden Button einzeln zu verdrahten.
    // nextItemInFocusChain() ist ein eingebauter QQuickItem-Methode
    // (traversiert die Fokus-Kette in Baum-Reihenfolge), funktioniert
    // auch, wenn `root` selbst (noch) nicht fokussiert ist - dient dann
    // als Startpunkt fürs allererste Tab (siehe jeweilige View:
    // onActiveChanged ruft view.forceActiveFocus(), NICHT auf einen
    // konkreten Button - der erste Tab-Druck springt von dort aus zum
    // ersten echten Button).
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            const win = root.Window.window
            const current = (win && win.activeFocusItem) ? win.activeFocusItem : root
            const next = current.nextItemInFocusChain(event.key === Qt.Key_Tab)
            if (next) next.forceActiveFocus()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
            root.escapePressed()
            event.accepted = true
        }
    }

    // An welcher Bildschirmkante angedockt - "top" (Insel) oder "bottom"
    // (Dock). Bestimmt Richtung von `y` beim Floaten UND welche Ecken im
    // angedockten Zustand eckig sind (immer die, die an der Kante kleben).
    property string edge: "top"
    readonly property bool _dockedAtTop: root.edge === "top"

    // Abstand zur Bildschirmkante im "floating"-Zustand (siehe unten) -
    // wird auch von IslandRoot.qml/Dock.qml gelesen, um dem Fenster genug
    // Höhe zu geben.
    property int floatingGap: 6

    // Jedes MorphItem sagt per `floating`, ob es angedockt an der
    // Bildschirmkante sitzen soll (nur PeekView: floating=false) oder als
    // eigenständige, losgelöste Pille schwebt (alles andere, Standard).
    // Angedockt: bündig mit der Kante (y=0), an der Kante eckig
    // ("Notch"-Look). Floating: mit Abstand zur Kante (y=floatingGap bzw.
    // von der Kante weg je nach edge), rundum abgerundet. Der Wechsel
    // dazwischen ist selbst Teil des Morphs (Behavior on y/Radius unten) -
    // genau das "erst rausfahren, dann schweben".
    readonly property bool _targetFloating: root._targetItem ? root._targetItem.floating : true

    // Gate für Breite/Höhe (siehe width/height unten): y/Ecken reagieren
    // SOFORT auf _targetFloating (Phase 1 - Position/Andocken bewegt sich
    // los, noch mit der ALTEN Größe). _floating zieht erst NACH, sobald
    // diese Bewegung eingeschwungen ist (siehe _onSpringSettled) - GENAU
    // DANN erst dürfen Breite/Höhe sich Richtung Ziel bewegen (Phase 2).
    // Ergebnis: erst bewegt/dockt sich die Fläche, DANN ändert sich ihre
    // Größe - in beide Richtungen symmetrisch, statt dass beim Schließen
    // Form und Position gleichzeitig lossausen (sah aus wie "sofort zum
    // Peek transformiert, das dann erst runterrutscht").
    property bool _floating: false

    // Nur im angedockten Zustand relevant - siehe MorphItem.qml.
    readonly property int _targetDockedOffset: root._targetItem ? root._targetItem.dockedOffset : 0

    // Aussehen kommt vom jeweils aktiven MorphItem (cornerRadius/
    // surfaceColor/borderColor, siehe MorphItem.qml) - Fallback auf Theme,
    // solange (kurz beim Start) noch kein target gültig ist.
    readonly property real _targetRadius: root._targetItem ? root._targetItem.cornerRadius : Theme.metrics.radius
    readonly property color _targetSurfaceColor: root._targetItem ? root._targetItem.surfaceColor : Theme.colors.background
    readonly property color _targetBorderColor: root._targetItem ? root._targetItem.borderColor : Theme.colors.border

    // Kinder landen automatisch in einem eigenen Content-Layer, NICHT
    // direkt auf `surface` - so bleibt "Fläche" und "Inhalt" sauber
    // getrennt, obwohl man sie beim Nutzen (IslandShape.qml/DockContent-
    // artige Verwendung) einfach gemeinsam als Kinder von MorphContainer
    // hinschreibt.
    default property alias content: contentLayer.data

    function _find(name) {
        for (const c of contentLayer.children) {
            if (c.name === name) return c
        }
        return null
    }

    readonly property var _targetItem: root._find(root.target)

    // Größte Breite/Höhe über ALLE registrierten MorphItems hinweg -
    // ändert sich nur, wenn Views hinzukommen/wegfallen, NICHT während
    // einer Animation. IslandRoot.qml/Dock.qml nutzen das, um das
    // eigentliche Wayland-Fenster fix auf diese Maße zu setzen, statt es
    // bei jedem Animationsframe real nativ zu resizen (siehe dortiger
    // Kommentar - das war die Hauptursache fürs Stottern).
    readonly property real maxContentWidth: {
        let m = 0
        for (const c of contentLayer.children) m = Math.max(m, c.preferredWidth || 0)
        return m
    }
    readonly property real maxContentHeight: {
        let m = 0
        for (const c of contentLayer.children) m = Math.max(m, c.preferredHeight || 0)
        return m
    }

    // Wartet auf _sizeSettled (siehe unten) - solange die Fläche noch am
    // Andocken/Ausfahren ist, bleibt die Größe bei ihrem ALTEN Wert stehen
    // (Selbstreferenz `: width`/`: height`, kein Zurück zu 0 o.ä.), erst
    // danach federt sie zum neuen Ziel.
    width: (root._sizeSettled && root._targetItem) ? root._targetItem.preferredWidth : width
    height: (root._sizeSettled && root._targetItem) ? root._targetItem.preferredHeight : height
    // Angedockt (nicht floating) UND dockedOffset > 0: rutscht zusätzlich
    // UM dockedOffset in die Kante rein (negativ bei edge:"top", positiv
    // bei edge:"bottom" - beide Richtungen schieben "weiter hinter die
    // Kante", nicht "von ihr weg" wie floatingGap das tut). Hängt an
    // _targetFloating (nicht _floating!) - DAS ist es, was Phase 1
    // überhaupt erst in Bewegung setzt (mit der noch alten Größe, siehe
    // width/height oben). _floating zieht erst NACH, sobald diese
    // Bewegung eingeschwungen ist (siehe _onSpringSettled) - wäre y schon
    // an _floating gebunden, würde sich y nie ändern (Henne-Ei), die
    // Fläche bliebe für immer in der alten Form stecken.
    // Höhe, mit der die y-Formel unten rechnet: WÄHREND Phase 1 (Position
    // bewegt sich noch, Größe ist gesperrt, siehe width/height oben) die
    // AKTUELLE (eingefrorene) Höhe - sonst würde die noch große Fläche auf
    // die Zielposition der KLEINEN Höhe rutschen und über den Bildschirm-
    // rand hinausragen. AB Phase 2 (Größe schon freigegeben) dagegen die
    // FESTE Zielhöhe statt der gerade laufenden - Grund: eine y-Feder, die
    // schon zur Ruhe gekommen war (Phase 1 fertig) und dann einem sich
    // JEDEN Frame weiterbewegenden Ziel (der live schrumpfenden Höhe)
    // hinterherjagen soll, kam beobachtbar nie wirklich in Gang (blieb
    // scheinbar stehen, sprang erst ganz am Ende auf die Zielposition) -
    // mit einem EINMALIGEN, festen neuen Ziel läuft dieselbe Feder normal.
    readonly property bool _sizeSettled: root._floating === root._targetFloating
    readonly property real _yHeightBasis: (root._sizeSettled && root._targetItem) ? root._targetItem.preferredHeight : root.height

    y: {
        if (root._targetFloating) {
            return root._dockedAtTop
                ? root.floatingGap
                : (root.parent ? root.parent.height - root._yHeightBasis - root.floatingGap : 0)
        }
        return root._dockedAtTop
            ? -root._targetDockedOffset
            : (root.parent ? root.parent.height - root._yHeightBasis + root._targetDockedOffset : 0)
    }

    // SpringAnimation statt einer Easing-Kurve: reagiert auf die
    // tatsächliche Distanz statt eine feste Kurve in fester Dauer
    // abzuspulen - wirkt bei Breite/Höhe, die sich oft unterschiedlich
    // stark ändern, wie EIN zusammenhängendes physisches Morphen.
    // spring = wie "straff" die Feder ist (höher = schneller/direkter),
    // damping = wie schnell das Nachschwingen abklingt (höher = ruhiger,
    // niedriger = mehr Wackeln). Dieselbe Feder für y - soll sich wie
    // derselbe physische Körper anfühlen, nicht wie eine separate
    // Animation, die zufällig gleichzeitig läuft.
    Behavior on width {
        SpringAnimation { id: widthAnim; spring: Config.surfaceSpring.spring; damping: Config.surfaceSpring.damping; mass: Config.surfaceSpring.mass; epsilon: Config.surfaceSpring.epsilon }
    }
    Behavior on height {
        SpringAnimation { id: heightAnim; spring: Config.surfaceSpring.spring; damping: Config.surfaceSpring.damping; mass: Config.surfaceSpring.mass; epsilon: Config.surfaceSpring.epsilon }
    }
    Behavior on y {
        SpringAnimation { id: yAnim; spring: Config.surfaceSpring.spring; damping: Config.surfaceSpring.damping; mass: Config.surfaceSpring.mass; epsilon: Config.surfaceSpring.epsilon }
    }

    property bool _pendingActivate: false
    property bool _leaveDone: false

    onTargetChanged: {
        for (const c of contentLayer.children) {
            if (c.name !== root.target) c.active = false
        }
        root._pendingActivate = true
        root._leaveDone = false
        leaveTimer.restart()

        // Nur beim AUSFAHREN (docked -> floating, z.B. Dock öffnet) wird
        // die Breiten/Höhen-Sperre sofort aufgehoben - Größe UND Position
        // federn dann gleichzeitig los, wie ursprünglich (sah beim Öffnen
        // schon gut aus). Beim ANDOCKEN (floating -> docked, z.B. Dock
        // schließt) bleibt _floating absichtlich UNVERÄNDERT (noch
        // true/floating) - das sperrt width/height weiter (siehe oben),
        // bis _onSpringSettled sie nach Abschluss der reinen
        // Positionsbewegung freigibt. Asymmetrisch mit Absicht: Öffnen
        // simultan, Schließen sequenziell (erst Position, dann Größe).
        //
        // WICHTIG: hier bewusst NICHT root._targetFloating verwenden - die
        // readonly property ist in GENAU DIESEM Handler noch nicht
        // aktualisiert (hängt an _targetItem, das selbst erst über eine
        // eigene Bindung neu ausgewertet wird - Reihenfolge relativ zu
        // diesem Signal-Handler nicht garantiert). Frisch nachschlagen
        // vermeidet den veralteten Wert.
        const freshItem = root._find(root.target)
        if (freshItem && freshItem.floating) {
            root._floating = true
        }
    }

    // Aktiviert das Ziel-Item NUR, wenn wirklich beide Bedingungen erfüllt
    // sind. Wird von drei Stellen aus aufgerufen (Leave-Timer fertig,
    // width fertig eingeschwungen, height fertig eingeschwungen) - welche
    // davon zuletzt eintrifft, aktiviert. Rein bedingungsbasiert, kein
    // Raten über Dauern -> robust gegen beliebig viele Unterbrechungen.
    function _tryActivate() {
        if (!root._pendingActivate) return
        if (!root._leaveDone) return
        if (widthAnim.running || heightAnim.running || yAnim.running) return
        root._pendingActivate = false
        const item = root._find(root.target)
        if (item) item.active = true
    }

    // Wird aufgerufen, sobald IRGENDEINE der drei Federn (width/height/y)
    // zur Ruhe kommt. Zwei Aufgaben, je nachdem WELCHE Phase gerade läuft:
    // 1) Phase 1 (Andocken/Ausfahren) fertig, Größe hinkt noch hinterher
    //    (_floating != _targetFloating) -> jetzt erst _floating umschalten,
    //    das setzt width/height oben frei -> Phase 2 (Größe) startet von
    //    selbst über deren Behavior. NICHT gleichzeitig aktivieren -
    //    sonst poppt der Inhalt rein, während die Fläche noch wächst.
    // 2) Beide Phasen fertig (_floating == _targetFloating, nichts läuft
    //    mehr) -> ganz normal wie vorher aktivieren.
    function _onSpringSettled() {
        if (root._floating !== root._targetFloating) {
            // NICHT nur auf yAnim.running verlassen: die Feder kann GENAU
            // in diesem Moment zufällig "nicht laufend" sein (z.B. Rest
            // einer ANDEREN, gerade erst abgeschlossenen Bewegung), auch
            // wenn y sich für DIESEN Phasenwechsel noch gar nicht Richtung
            // Ziel bewegt hat - das kippte _floating sonst sofort um, statt
            // erst nach der Positionsbewegung (siehe Bugreport: "Peek wird
            // hoch bewegt, dann Größe" trat genau deswegen wieder auf).
            // Zusätzlich numerisch prüfen, ob y wirklich am erwarteten
            // Phase-1-Ziel angekommen ist.
            const expectedY = root._targetFloating
                ? (root._dockedAtTop ? root.floatingGap : (root.parent ? root.parent.height - root.height - root.floatingGap : 0))
                : (root._dockedAtTop ? -root._targetDockedOffset : (root.parent ? root.parent.height - root.height + root._targetDockedOffset : 0))
            if (yAnim.running || Math.abs(root.y - expectedY) > 1) return
            root._floating = root._targetFloating
            return
        }
        root._tryActivate()
    }

    Timer {
        id: leaveTimer
        interval: root.leaveDuration
        onTriggered: { root._leaveDone = true; root._tryActivate() }
    }

    Connections {
        target: widthAnim
        function onRunningChanged() { if (!widthAnim.running) root._onSpringSettled() }
    }
    Connections {
        target: heightAnim
        function onRunningChanged() { if (!heightAnim.running) root._onSpringSettled() }
    }
    Connections {
        target: yAnim
        function onRunningChanged() { if (!yAnim.running) root._onSpringSettled() }
    }

    // --- Schatten: mehrere gestapelte, halbtransparente Kopien der
    // Fläche, größer + blasser je weiter außen. Bewusst KEIN DropShadow
    // (Qt5Compat.GraphicalEffects) - dieses Projekt vermeidet Shader-
    // Effekte grundsätzlich (siehe LucideIcon.qml: unzuverlässig auf
    // manchen Setups), das hier sind nur zusätzliche Rectangles UNTER der
    // eigentlichen Fläche. Kein echtes Gaussian-Blur, aber mit GENUG
    // Layern (8, quadratisch abnehmende Deckkraft) verschwimmen die
    // Kanten zwischen den Stufen genug, um nicht mehr als Stufen
    // aufzufallen (2 Layer sahen sichtbar treppig aus). Vor `surface`
    // deklariert -> liegt automatisch dahinter (kein z nötig).
    //
    // surfaceRef statt direktem Zugriff auf die `surface`-Id: Inline-
    // components haben KEINEN Zugriff auf IDs aus dem umgebenden Scope
    // (eigener, isolierter Geltungsbereich) - surface muss also als
    // Property reingereicht werden, gesetzt an der Instanzierungsstelle
    // weiter unten (die liegt im umgebenden Scope, dort ist die Id sichtbar).
    component ShadowLayer: Rectangle {
        property int spread: 4
        property Item surfaceRef

        anchors.fill: surfaceRef
        anchors.margins: -spread
        topLeftRadius: surfaceRef && surfaceRef.topLeftRadius > 0 ? surfaceRef.topLeftRadius + spread : 0
        topRightRadius: surfaceRef && surfaceRef.topRightRadius > 0 ? surfaceRef.topRightRadius + spread : 0
        bottomLeftRadius: surfaceRef && surfaceRef.bottomLeftRadius > 0 ? surfaceRef.bottomLeftRadius + spread : 0
        bottomRightRadius: surfaceRef && surfaceRef.bottomRightRadius > 0 ? surfaceRef.bottomRightRadius + spread : 0
    }

    readonly property int _shadowLayerCount: 8
    Repeater {
        model: root._shadowLayerCount
        delegate: ShadowLayer {
            required property int index
            // Spread wächst linear (2px pro Layer), Deckkraft fällt
            // quadratisch (dicht am Rand, schnell auslaufend) - fühlt
            // sich dadurch eher wie ein echter weicher Schatten an als
            // eine lineare Rampe.
            spread: (index + 1) * 2
            surfaceRef: surface
            color: Qt.rgba(0, 0, 0, 0.11 * Math.pow(1 - index / root._shadowLayerCount, 2))
        }
    }

    Rectangle {
        id: surface
        anchors.fill: parent

        // Hängt an _targetFloating, genau wie y (siehe dort) - die Ecken
        // schwenken zusammen MIT der Positionsbewegung (Phase 1), nicht
        // erst danach.
        topLeftRadius: root._dockedAtTop ? (root._targetFloating ? root._targetRadius : 0) : root._targetRadius
        topRightRadius: root._dockedAtTop ? (root._targetFloating ? root._targetRadius : 0) : root._targetRadius
        bottomLeftRadius: root._dockedAtTop ? root._targetRadius : (root._targetFloating ? root._targetRadius : 0)
        bottomRightRadius: root._dockedAtTop ? root._targetRadius : (root._targetFloating ? root._targetRadius : 0)
        color: root._targetSurfaceColor
        border.width: 1
        border.color: root._targetBorderColor
        clip: true

        Behavior on topLeftRadius { NumberAnimation { duration: Config.surfaceCornerDuration; easing.type: Easing.OutCubic } }
        Behavior on topRightRadius { NumberAnimation { duration: Config.surfaceCornerDuration; easing.type: Easing.OutCubic } }
        Behavior on bottomLeftRadius { NumberAnimation { duration: Config.surfaceCornerDuration; easing.type: Easing.OutCubic } }
        Behavior on bottomRightRadius { NumberAnimation { duration: Config.surfaceCornerDuration; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Config.surfaceCornerDuration } }
        Behavior on border.color { ColorAnimation { duration: Config.surfaceCornerDuration } }

        Item {
            id: contentLayer
            anchors.fill: parent
        }
    }

    // Eigene, NICHT geclippte Ebene für Inhalte, die über die Pille
    // hinausragen müssen (Tooltips, Kontextmenüs) - `surface` oben hat
    // bewusst `clip: true` (damit morphender Inhalt nicht über die Pille
    // hinaus sichtbar wird), das schneidet aber JEDEN Nachfahren ab,
    // unabhängig von Fenstergröße/Maske. Popups reparenten sich selbst
    // hierher (siehe AppsView.qml) statt in contentLayer zu bleiben - liegt
    // als Geschwister von `surface`, GESCHWISTER werden von dessen clip
    // nicht erfasst. Deckt dasselbe Gebiet wie `root` ab (inkl. eventuellem
    // Popup-Headroom, den das Fenster drumherum bereitstellt, siehe Dock.qml).
    Item {
        id: popupLayer
        anchors.fill: parent
    }
    readonly property alias popupLayer: popupLayer
}
