import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import "../.."
import "../../services" as Services

// Einstiegspunkt der Dynamic Island (siehe shell.qml). Reine Fenster- und
// Zustandsverwaltung - "wohin will die Insel gerade" (effectiveTarget).
// WIE das animiert ankommt (Größe morphen, Inhalt ein-/ausblenden) weiß
// diese Datei bewusst NICHT - das steckt komplett in MorphContainer.qml +
// MorphItem.qml (siehe modules/island/README.md).
//
// "peek" (der winzige Sliver im Ruhezustand) ist kein Sonderfall mehr,
// sondern einfach ein MorphItem wie jede andere View auch (views/PeekView.qml).
//
// Neue Ansicht hinzufügen (z.B. eigenes Feature):
//   1) modules/island/views/MeinFeatureView.qml anlegen, Root-Element
//      `MorphItem { name: "meinfeature"; preferredWidth: ...; preferredHeight: ...; ... }`
//   2) in IslandShape.qml eine `Views.MeinFeatureView { islandRoot: shape.islandRoot }`-
//      Zeile einhängen
//   3) irgendwo einen Trigger bauen, der `islandRoot.openView("meinfeature")`
//      aufruft (z.B. ein Icon in ControlCenterView, siehe dortige
//      Shortcut-Zeile)
Scope {
    id: root

    required property var screen

    // --- Einstellungen ---
    property int triggerHeight: 6
    property int hideDelay: Config.hideDelay
    property int notifyDuration: 5000
    property int viewModeIdleTimeout: Config.viewModeIdleTimeout  // "zurück zu default", wenn 1min nicht gehovert wird

    // --- Status ---
    property bool triggerHovered: false
    property bool contentHovered: false
    property bool forceReveal: false        // true während z.B. eine Notification "reinpoppt"
    // true, seit die Insel per externem Trigger (Hyprland-Keybind, siehe
    // ShellViewState.qml) geöffnet wurde,
    // OHNE dass dafür gehovert wird - hält die Insel offen (statt wie
    // sonst nach hideDelay zu verschwinden, sobald keine Maus im Spiel
    // ist). KEIN dauerhaftes Anpinnen mehr - endet automatisch nach
    // Config.hotkeyOpenDuration (siehe hotkeyHoldTimer unten), UNABHÄNGIG
    // davon, ob je gehovert wurde. Wird die Insel VOR Ablauf tatsächlich
    // gehovert, kippt es trotzdem schon dann auf false (siehe
    // onContentHoveredChanged unten, stoppt auch den Timer) - ab da gilt
    // ganz normales Hover-Verhalten (weg = 350ms später zu). Der Timer ist
    // also nur die obere Grenze, kein Mindest-Offenbleiben.
    property bool hotkeyHeldOpen: false
    property bool revealed: false
    property string viewMode: "default"     // welche View geöffnet werden soll, sobald nicht mehr "peek"

    // Navigationsverlauf für closeView(): jede bewusste Vorwärts-Navigation
    // (openView(), s.u.) legt die bisherige viewMode hier ab, bevor sie
    // wechselt - closeView() springt dadurch zur zuletzt aktiven View
    // zurück statt immer fest zu "default". Rein automatische Wechsel
    // (Hover-Eskalation zu "info", Idle-Reset) laufen bewusst NICHT über
    // openView() und landen deshalb auch nicht auf dem Stack - nur was der
    // Nutzer aktiv angesteuert hat, soll beim Zurückspringen wieder
    // auftauchen. Notifications sind die Ausnahme: die aktuelle View wird
    // VOR dem erzwungenen Wechsel zu "notify" separat gemerkt (s.u.), damit
    // man nach dem Wegklicken/Ablaufen des Popups wieder dort landet, wo
    // man vorher war.
    property var _viewHistory: []

    // Wohin die Insel gerade eigentlich will. "peek", solange sie weder
    // gehovert wird noch zwangsweise offen ist - sonst viewMode. Das ist
    // die einzige Schnittstelle zu IslandShape/MorphContainer.
    readonly property string effectiveTarget: (root.revealed || root.forceReveal) ? root.viewMode : "peek"

    // Bleibt true, ab dem Moment wo eine Notification eintrifft, bis die
    // Insel mindestens einmal (egal in welcher View) gehovert wurde -
    // siehe onContentHoveredChanged. Verhindert, dass die Default-Ansicht
    // mit der Glocke (siehe DefaultView.qml) sofort wieder in "peek"
    // verschwindet, nur weil das kurze Notify-Popup (siehe notifyTimer)
    // vorbei ist, ohne dass man's überhaupt gesehen hat.
    property bool notificationUnseen: false

    onTriggerHoveredChanged: updateVisibility()
    onContentHoveredChanged: {
        if (root.contentHovered) {
            root.notificationUnseen = false
            // Per Hotkey geöffnet (siehe hotkeyHeldOpen oben) UND jetzt
            // gehovert -> zählt als Aktivität, verlängert den Hold (siehe
            // noteActivity()) statt ihn zu BEENDEN. hotkeyHeldOpen
            // NICHT hart auf false setzen: solange tatsächlich gehovert
            // wird, hält updateVisibility() ohnehin schon offen (siehe
            // contentHovered dort, unabhängig von hotkeyHeldOpen) - ein
            // hartes Löschen hier brachte nur einen Nachteil, keinen
            // Vorteil: ein kurzes, beiläufiges Antippen der Maus (Cursor
            // steht zufällig in der Nähe, wandert gleich weiter) löschte
            // den Hold DAUERHAFT, obwohl der Hover selbst gleich wieder
            // vorbei war - die Insel klappte dann über den normalen
            // hideTimer (350ms) sofort zu, obwohl die Hold-Zeit
            // eigentlich noch lief (live beobachtet: "Hold greift nicht,
            // View geht sofort wieder zu peek").
            root.noteActivity()
        }
        updateVisibility()
        // Zweite Hover-Stufe: die (kleine) Default-Ansicht selbst gehovert
        // -> zur erweiterten Info-Ansicht eskalieren. Nur von "default"
        // aus - wer schon in einer anderen View ist, soll nicht durch
        // bloßes Hovern woanders hinspringen.
        if (root.contentHovered && root.viewMode === "default") {
            root.viewMode = "info"
        }
    }

    function updateVisibility() {
        const forceOpenForNotification = root.notificationUnseen && Services.Notifications.count > 0
        if (triggerHovered || contentHovered || forceReveal || forceOpenForNotification || hotkeyHeldOpen) {
            hideTimer.stop()
            idleResetTimer.stop()
            revealed = true
        } else {
            hideTimer.restart()
            idleResetTimer.restart()
        }
    }

    // notificationUnseen hält die Insel offen, OHNE dass dafür gehovert
    // wird - ändert sich also außerhalb der üblichen Hover-Trigger. Wird
    // eine Notification anderweitig weggeklickt (z.B. "Alle löschen" im
    // Control Center), während die Insel deswegen offen steht, muss
    // updateVisibility() das mitbekommen, sonst bliebe sie offen stecken.
    Connections {
        target: Services.Notifications
        function onCountChanged() { root.updateVisibility() }
    }

    // "info" wurde rein passiv durchs Hovern erreicht (keine bewusste
    // Klick-Aktion wie bei Music/Control Center/...) - soll sich deshalb
    // auch genauso beiläufig wieder schließen: sofort, ohne die normale
    // Gnadenfrist, sobald man nicht mehr hovert.
    readonly property int effectiveHideDelay: root.viewMode === "info" ? 0 : root.hideDelay

    Timer {
        id: hideTimer
        interval: root.effectiveHideDelay
        onTriggered: root.revealed = false
    }




    // Manuell geöffnete Views (Music, Control Center, ...) blieben bisher
    // für immer offen (bis man aufs "x" tippt) - selbst wenn man die Insel
    // längst nicht mehr anschaut. Nach viewModeIdleTimeout ohne jeden
    // Hover (weder Trigger- noch Content-Zone) springt viewMode zurück auf
    // "default". Läuft unabhängig von hideTimer (der nur die Sichtbarkeit/
    // "peek" regelt, viel kürzer) - wird bei jedem Hover neu gestartet.
    Timer {
        id: idleResetTimer
        interval: root.viewModeIdleTimeout
        // Kompletter Reset, nicht nur viewMode: eine Navigationskette, die
        // hier "verlassen" wurde, soll nicht Minuten später aus einem
        // völlig neuen Kontext heraus per closeView() wieder auftauchen.
        onTriggered: {
            root.viewMode = "default"
            root._viewHistory = []
            root.hotkeyHeldOpen = false
            hotkeyHoldTimer.stop()
        }
    }

    // Springt zur zuletzt aktiven View zurück (siehe _viewHistory oben) -
    // erst wenn der Verlauf leer ist, wird "default" zum Fallback. Von
    // jeder View aus aufrufbar, z.B. über ein "x"-Icon.
    function closeView() {
        // Falls "notify" gerade per Timer-Ablauf (s.u.) UND manuell (X-
        // Button in NotifyView.qml) geschlossen wird, würde der Timer sonst
        // verzögert noch ein zweites Mal feuern und uns aus der View
        // rausreißen, zu der man inzwischen weiternavigiert ist.
        if (root.viewMode === "notify") notifyTimer.stop()
        root.viewMode = root._viewHistory.length > 0 ? root._viewHistory.pop() : "default"
        // Ein per Hotkey offengehaltenes Panel endet mit jedem bewussten
        // Schließen (x, Escape, nochmaliger Tastendruck - siehe
        // toggleViewExternally unten) sofort, nicht erst nach Timer-
        // Ablauf - sonst bliebe die Insel trotz "geschlossen" weiter
        // sichtbar, weil hotkeyHeldOpen die einzige Bedingung in
        // updateVisibility() ist, die ohne Hover auskommt.
        root.hotkeyHeldOpen = false
        hotkeyHoldTimer.stop()
    }

    // Öffnet/schließt eine beliebige View manuell (Klick auf ein Icon).
    // Erneuter Klick auf dieselbe View = Schließen (über closeView() oben -
    // springt zur View DAVOR zurück, nicht fest zu "default"). Jede echte
    // Vorwärts-Navigation merkt sich die bisherige viewMode auf
    // _viewHistory, bevor sie wechselt.
    function openView(name) {
        if (root.viewMode === name) {
            root.closeView()
            return
        }
        root._viewHistory.push(root.viewMode)
        root.viewMode = name
    }

    // Sorgt dafür, dass die Notification-Liste sichtbar ist (jetzt Teil von
    // InfoView.qml, kein eigenes "list"-Ziel mehr). BEWUSST kein Toggle wie
    // openView() sonst: Hovern der Insel-Fläche eskaliert automatisch
    // default->info (siehe onContentHoveredChanged oben) - bis ein Klick
    // auf die Glocke im Default-View überhaupt registriert wird, ist
    // viewMode praktisch immer schon "info" (Hover kommt zwangsläufig vor
    // dem Klick). Mit openView()s Toggle-Logik würde ausgerechnet dieser
    // Klick "info" sofort wieder zuklappen, statt es offen zu halten -
    // deshalb hier: nur öffnen, wenn nicht schon offen, nie schließen.
    function showNotifications() {
        if (root.viewMode !== "info") root.openView("info")
    }

    // Externer Trigger für eine View per Hyprland-Keybind (siehe
    // ShellViewState.qml) - ganz ohne Hover,
    // deshalb hotkeyHeldOpen statt nur openView() (das würde die Insel
    // zwar auf die Ziel-View schalten, aber updateVisibility() ohne jede
    // Hover-Bedingung sofort wieder in hideTimer laufen lassen - die
    // Insel wäre nie tatsächlich ZU SEHEN). Bereits offen -> zu, sonst
    // offenhalten + öffnen: normales Toggle-Gefühl für den Tastendruck.
    // Eine Funktion für beide Trigger-Quellen statt duplizierter Logik
    // pro View.
    function toggleViewExternally(name) {
        console.warn("SHELLVIEW DEBUG toggleViewExternally name=" + name + " currentViewMode=" + root.viewMode)
        if (root.viewMode === name) {
            root.closeView()
        } else {
            root.hotkeyHeldOpen = true
            hotkeyHoldTimer.restart()
            root.openView(name)
        }
        root.updateVisibility()
        console.warn("SHELLVIEW DEBUG after toggle viewMode=" + root.viewMode + " revealed=" + root.revealed + " effectiveTarget=" + root.effectiveTarget)
    }

    // Obere Grenze für hotkeyHeldOpen (siehe dort) - läuft ab, sobald per
    // Hotkey geöffnet wird, gestoppt bei jedem vorzeitigen Schließen/
    // Hover (siehe closeView()/onContentHoveredChanged/idleResetTimer).
    // Dauer über Config.qml einstellbar statt hier hart codiert, wie die
    // übrigen Morph-Timings dort auch.
    Timer {
        id: hotkeyHoldTimer
        interval: Config.hotkeyOpenDuration
        onTriggered: {
            root.hotkeyHeldOpen = false
            root.updateVisibility()
        }
    }

    // Von Views/Fokus-Tracking aufrufbar, wenn eine bewusste Aktion
    // stattfindet, die KEIN Hover ist - Pfeiltasten-Navigation im
    // Wahlscheiben-Wallpaper-Picker (siehe WallpaperView.qml/
    // onCurrentIndexChanged) UND Tab/Umschalt+Tab zum Durchschalten der
    // Buttons (siehe activeFocusItemChanged-Connections auf islandWindow
    // unten - NICHT über ein eigenes Tab-Signal von MorphContainer.qml:
    // Items mit activeFocusOnTab:true übernehmen die Tab-Navigation ab dem
    // zweiten Button intern über Qt Quicks eingebaute Fokus-Kette, bevor das
    // je bei einem Keys.onPressed-Handler ankommt - live verifiziert, ein
    // Tab-Signal dort hätte nur beim allerersten Tab gefeuert).
    // contentHovered deckt nur die Maus ab; wer eine View rein per Tastatur
    // bedient (Maus liegt still irgendwo anders), würde sonst trotz
    // durchgehender Aktivität nach Ablauf einfach rausfliegen, weil weder
    // hotkeyHoldTimer noch idleResetTimer davon je mitbekommen.
    // Verlängert beide Timer hier einfach um ein weiteres volles Intervall,
    // statt sie (wie Hover das bei hotkeyHoldTimer tut) ganz zu beenden -
    // eine einzelne Taste soll die View nicht schon dauerhaft "entpinnen".
    // idleResetTimer NUR neu starten, wenn er gerade tatsächlich läuft
    // (läuft nur, während NICHT gehovert wird, siehe updateVisibility()) -
    // sonst würde ein Tab-Druck WÄHREND man die Insel gerade hovert den
    // Timer fälschlich erst in Gang setzen, obwohl er dort laut Design gar
    // nicht laufen soll.
    function noteActivity() {
        if (root.hotkeyHeldOpen) hotkeyHoldTimer.restart()
        if (idleResetTimer.running) idleResetTimer.restart()
    }

    // IslandRoot existiert einmal PRO BILDSCHIRM (siehe shell.qml/Variants),
    // ShellViewState ist aber ein globaler Singleton - sein
    // toggleRequested()-Signal erreicht dadurch ALLE Instanzen
    // gleichzeitig. Ohne diesen Filter öffnete sich die View per Hotkey auf
    // jedem Monitor gleichzeitig (live gemeldeter Bug). Hyprland.monitorFor()
    // bildet root.screen auf den zugehörigen HyprlandMonitor ab, .focused
    // ist true für genau den Monitor, auf dem gerade der Fokus liegt - bei
    // follow_mouse=1 (siehe general.lua) faktisch auch "wo die Maus ist".
    // Fallback true, falls das Mapping mal fehlschlägt (kein Hyprland-
    // Monitor gefunden) - dann lieber wie vorher überall öffnen als gar
    // nirgends.
    function isFocusedScreen() {
        // Bei nur EINEM Bildschirm ist der Check unten strukturell
        // überflüssig (es gibt nichts, wonach zu filtern wäre) UND
        // riskant - lieber der ganze .focused-Kram gar nicht erst
        // angefasst. Live gemeldeter Bug (Single-Monitor-Setup, Submap
        // "shell", siehe bindings.lua): .focused lieferte false zurück,
        // obwohl `hyprctl monitors` denselben Monitor korrekt als
        // focused:true auswies - der Hyprland.monitors-Cache war trotz
        // refreshMonitors() (s.u.) noch stale. Vermutete Ursache:
        // refreshMonitors() ist async, die anschließende Zeile liest also
        // noch den alten Stand. Bei den ursprünglichen Direkt-Binds
        // (SUPER+A/W, vor der "shell"-Submap) fiel das nie auf, weil dabei
        // durch normale Mausbewegung nebenbei ohnehin echte Fokus-Events
        // reinkamen und den Cache zufällig warm hielten - die Submap
        // (zwei schnelle Tastendrücke hintereinander, Hände bleiben auf
        // der Tastatur) hat genau dieses Zufalls-Polster entfernt.
        if (Quickshell.screens.length <= 1) return true

        // War vorher Hyprland.refreshMonitors() + Hyprland.monitorFor(...).focused
        // - genau der oben vermutete Bug ist live bestätigt aufgetreten
        // (per qs ipc call, ohne Maus dazwischen): mon.focused lieferte
        // false für den laut `hyprctl monitors` tatsächlich fokussierten
        // Schirm, weil refreshMonitors() async ist und die Zeile direkt
        // danach noch den alten Stand liest - dadurch öffnete sich die
        // View auf KEINEM Bildschirm mehr.
        //
        // Hyprland.focusedMonitor statt monitorFor(...).focused: eine
        // eigene reaktive Property, die schon laufend über Hyprlands
        // "focusedmon>>"-IPC-Events aktuell gehalten wird (kein manuelles
        // Refresh, kein Race - die Events kommen ohnehin ständig rein).
        const mon = Hyprland.focusedMonitor
        console.warn("SHELLVIEW DEBUG isFocusedScreen screen=" + root.screen.name + " mon=" + mon + " mon.name=" + (mon ? mon.name : "null"))
        return mon ? mon.name === root.screen.name : true
    }

    // Ein einziger Handler für JEDEN per Hyprland-Keybind angesteuerten
    // View-Wechsel (Control Center, Wallpaper-Picker, Power-Menü,
    // Zwischenablage, Info/Benachrichtigungen, WLAN, Bluetooth, Default) -
    // siehe ShellViewState.qml für die Begründung, warum das EIN
    // generisches Singleton mit Namens-Payload ist statt eines pro View.
    // name kommt 1:1 aus `qs ipc call shell toggle <name>` (siehe Submap
    // "shell" in Configs/hyprland/.config/hypr/modules/bindings.lua) und
    // muss exakt dem `name:`-Property der Ziel-View entsprechen.
    Connections {
        target: ShellViewState
        function onToggleRequested(name) {
            console.warn("SHELLVIEW DEBUG onToggleRequested name=" + name + " screen=" + root.screen.name + " isFocusedScreen=" + root.isFocusedScreen())
            if (root.isFocusedScreen()) root.toggleViewExternally(name)
        }
    }

    // Polkit-Authentifizierungsanfragen laufen NICHT mehr über die Insel -
    // siehe modules/PolkitOverlay.qml (eigenes, nur einmal instanziiertes
    // Fenster statt einer View pro Bildschirm, siehe dortiger Kommentar für
    // die Begründung/Vorgeschichte dieses Wechsels).

    // Neue Notification -> Insel automatisch aufklappen + Notify-Ansicht
    // zeigen (außer Do-Not-Disturb ist aktiv - dann landet sie nur in der Liste).
    Connections {
        target: Services.Notifications
        function onLatestChanged() {
            if (!Services.Notifications.latest) return
            if (Services.Notifications.doNotDisturb) return
            root.notificationUnseen = true
            // Nicht über openView() (das würde bei zwei Notifications
            // hintereinander "notify" selbst auf den Verlauf legen, statt
            // der View davor - ein zweites closeView() wäre dann nötig, um
            // wirklich rauszukommen). Nur beim ERSTEN Wechsel zu "notify"
            // merken, ein bereits laufendes Notify-Popup überschreibt sich
            // selbst einfach (s. Notifications.qml/latest).
            if (root.viewMode !== "notify") root._viewHistory.push(root.viewMode)
            root.viewMode = "notify"
            root.forceReveal = true
            root.updateVisibility()
            notifyTimer.restart()
        }
    }

    // Auto-Dismiss nach notifyDuration - läuft über dieselbe closeView()
    // wie der manuelle X-Button in NotifyView.qml (springt zur View
    // zurück, die vor der Notification offen war, statt fest zu "default").
    Timer {
        id: notifyTimer
        interval: root.notifyDuration
        onTriggered: {
            root.forceReveal = false
            root.closeView()
            root.updateVisibility()
        }
    }

    // 1) Hover-Trigger an der obersten Bildschirmkante
    PanelWindow {
        id: triggerZone
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay

        anchors { top: true; left: true; right: true }
        implicitHeight: root.triggerHeight

        HoverHandler {
            onHoveredChanged: root.triggerHovered = hovered
        }
    }

    // 2) Die Insel selbst - immer voll geladen (kein Loader), damit die
    // Animation beim ersten Aufklappen nicht durch asynchrones
    // Instanziieren stockt oder "poppt".
    PanelWindow {
        id: islandWindow
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        // Layer-Shell-Surfaces bekommen standardmäßig GAR KEINEN
        // Keyboard-Fokus (richtig so für ein Panel, das meistens nur
        // gehovert/geklickt wird) - ohne das hier tippt man ins Leere,
        // selbst wenn ein TextField per forceActiveFocus() intern "Fokus"
        // zu haben glaubt (das ist nur Qt-seitiger Zustand, der Compositor
        // routet Tasten trotzdem nirgendwohin). OnDemand fordert Fokus nur
        // an, wenn tatsächlich ein Kind-Item aktiven Fokus hat (z.B. das
        // Username-TextField in GithubHeatmap.qml) - kein Exclusive, das
        // würde dauerhaft Fokus von anderen Fenstern klauen.
        //
        // AUSNAHME: hotkeyHeldOpen (siehe dort) - per Hyprland-Hotkey
        // geöffnet, OHNE dass die Maus je über der Insel war. OnDemand
        // "fordert" Fokus zwar an, der Compositor gewährt echten
        // Keyboard-Fokus für eine Layer-Shell-Surface aber offenbar nur
        // zuverlässig, wenn der Zeiger auch tatsächlich drüber ist (live
        // getestet: Escape landete beim Fenster unter der Maus, nicht bei
        // der - unsichtbar "fokussierten" - Insel). Exclusive erzwingt den
        // Fokus stattdessen unabhängig von der Zeigerposition - exakt das
        // Muster, das AppLauncher.qml für denselben Zweck schon nutzt
        // (WlrKeyboardFocus.Exclusive, solange LauncherState.open) - hier
        // nur auf das Zeitfenster von hotkeyHeldOpen begrenzt, damit
        // normales Hovern (z.B. nur die Uhr angucken) nicht dauerhaft
        // anderen Fenstern den Fokus klaut. (Polkit braucht hier KEINE
        // Sonderrolle mehr - siehe modules/PolkitOverlay.qml, das läuft
        // inzwischen als eigenes, separates Fenster mit eigenem
        // Exclusive-Fokus, nicht mehr über die Insel.)
        WlrLayershell.keyboardFocus: root.hotkeyHeldOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

        anchors { top: true; left: true; right: true }

        // WICHTIG: implicitHeight ist FIX auf die größte je vorkommende
        // Pillenhöhe gesetzt (shape.maxContentHeight, siehe
        // MorphContainer.qml) statt reaktiv an die gerade animierte Höhe
        // der Pille gebunden zu sein. Ein PanelWindow ist eine echte
        // Wayland-Surface - jede implicitHeight-Änderung löst ein
        // natives Resize (Buffer-Neuallokation + Compositor-Roundtrip)
        // aus, und das bei JEDEM einzelnen Animationsframe war die
        // Hauptursache fürs Stottern. Jetzt bleibt die Fenstergröße
        // während der gesamten Animation konstant, nur die Pille
        // (shape, ein normales QML-Item) ändert innerhalb davon ihre
        // Größe - reines Scenegraph-Rendering, kein Surface-Resize mehr.
        //
        // Der leere Rand um die kleinere Pille herum ist transparent und
        // damit unsichtbar, blockiert aber ohne Gegenmaßnahme trotzdem
        // Mausklicks für alles darunter - daher die mask: Region unten,
        // die Ein-/Ausgabe auf exakt die aktuelle Pillenfläche begrenzt.
        // +floatingGap, weil die Pille im "schwebenden" Zustand selbst
        // noch um floatingGap nach unten rutscht (siehe MorphContainer.qml).
        implicitHeight: shape.maxContentHeight + shape.floatingGap + 8

        mask: Region { item: shape }

        // Aktivitäts-Tracking für noteActivity() (Hold-/Auto-Close-Timer,
        // siehe dort): NICHT über einen eigenen Tab-Handler/Signal in
        // MorphContainer.qml - Items mit activeFocusOnTab:true
        // (MenuButton/ActionButton/Toggle) werden von Qt Quick INTERN per
        // eingebauter Tab-Chain-Navigation weitergeschaltet, BEVOR das über
        // Keys.onPressed-Bubbling bei einem zentralen Handler ankommen
        // würde - live verifiziert (ein Tab-Signal dort feuerte nur beim
        // ALLERERSTEN Tab-Druck einer Session, obwohl sichtbar mehrere
        // Buttons nacheinander den Fokusring bekamen). activeFocusItem
        // ändert sich dagegen bei JEDEM Fokuswechsel, ganz gleich ob durch
        // Tab, Klick oder Qt's eigene Chain-Navigation ausgelöst - genau
        // das zählt hier als Aktivität.
        //
        // PanelWindow selbst exponiert activeFocusItem NICHT direkt (Laden
        // schlug mit "Cannot assign to non-existent property" fehl) - über
        // shape.Window.window kommt man ans echte darunterliegende
        // QQuickWindow, exakt das Muster, das MorphContainer.qml
        // (root.Window.window) für denselben Zweck schon nutzt.
        Connections {
            target: shape.Window.window
            function onActiveFocusItemChanged() { root.noteActivity() }
        }

        HoverHandler {
            onHoveredChanged: root.contentHovered = hovered
        }

        IslandShape {
            id: shape
            islandRoot: root
        }
    }
}
