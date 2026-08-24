import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../.."
import "../../.."
import "../../../services" as Services

// Volle Dock-UI (angepinnte + laufende Apps + AppLauncher-Icon) - jetzt
// eine echte View wie in modules/island/views/, statt inline in
// DockShape.qml zu stecken. preferredWidth reagiert auf die tatsächliche
// Icon-Anzahl (rowLayout.implicitWidth) statt fest codiert zu sein -
// ändert sich nur, wenn Apps angepinnt/gestartet werden, federt dann aber
// genauso weich mit wie jeder andere Größenwechsel (siehe MorphContainer.qml).
MorphItem {
    id: view

    name: "dock"
    preferredWidth: rowLayout.implicitWidth + Theme.metrics.spacing * 2
    preferredHeight: dockRoot.expandedHeight
    // Volles Pop-in (mit Scale-Feder) ließ Icons beobachtbar unsichtbar
    // bleiben, bis irgendein unabhängiger Repaint sie zeigte (siehe
    // MorphItem.staggerContent) - vermutlich die Kombination aus
    // asynchron ladenden IconImages + Start bei scale:0.85. Nur Opacity
    // fadet rein, das reicht als sanfter Einstieg ohne das Risiko.
    staggerScale: false
    borderColor: Theme.colors.border

    required property var dockRoot
    // NICHT geclippte Ebene (siehe MorphContainer.qml) - Tooltip und
    // Kontextmenü reparenten sich dorthin, damit sie nicht am `clip: true`
    // der Pillen-Fläche abgeschnitten werden.
    required property var popupLayer

    // Wie viele Kacheln GERADE einen sichtbaren Tooltip zeigen - normalerweise
    // max. 1 (immer nur ein Icon gehovert), ein Zähler statt eines einzelnen
    // bool ist aber robuster gegen Überlappungen beim schnellen Wechsel
    // zwischen Icons (kurz könnten zwei gleichzeitig true sein). Zusammen mit
    // contextMenu.menuVisible steuert das, ob Dock.qml die Fenstermaske um
    // zusätzlichen Platz ÜBER der Pille erweitert - Tooltips UND das
    // Kontextmenü ragen über die eigentliche Dock-Fläche hinaus, und die
    // sitzt in einem bewusst klein gehaltenen Fenster (siehe Dock.qml) -
    // ohne das würden sie am Fensterrand abgeschnitten.
    property int _visibleTooltipCount: 0
    readonly property bool popupNeedsExtraSpace: view._visibleTooltipCount > 0 || contextMenu.menuVisible

    // Eine Dock-Kachel (laufende App und/oder angepinnter Favorit) - als
    // Inline-Component, weil sie in ZWEI Repeatern gebraucht wird (siehe
    // unten: angepinnte Gruppe + laufende-aber-nicht-angepinnte Gruppe).
    component DockTile: Item {
        id: tile
        required property var modelData

        readonly property bool running: modelData.toplevels.length > 0
        property bool hovered: iconHover.hovered
        property bool tooltipReady: false

        onHoveredChanged: {
            if (tile.hovered) {
                tooltipDelay.restart()
            } else {
                tooltipDelay.stop()
                tile.tooltipReady = false
            }
        }
        // Hält view._visibleTooltipCount synchron - Component.onDestruction
        // zieht ab, FALLS die Kachel mit sichtbarem Tooltip verschwindet
        // (z.B. App wird während des Hovers geschlossen), sonst bliebe der
        // Zähler dauerhaft zu hoch stehen.
        onTooltipReadyChanged: {
            view._visibleTooltipCount += tile.tooltipReady ? 1 : -1
            if (tile.tooltipReady) tooltip.reposition()
        }
        Component.onDestruction: if (tile.tooltipReady) view._visibleTooltipCount--

        Timer {
            id: tooltipDelay
            interval: 400
            onTriggered: tile.tooltipReady = true
        }

        Layout.preferredWidth: dockRoot.iconBoxSize
        Layout.preferredHeight: dockRoot.iconBoxSize
        Layout.alignment: Qt.AlignBottom

        // Der komplette VISUELLE Teil (Hintergrund, Icon, Hover-Skalierung)
        // steckt in einem eigenen inneren Item statt direkt auf tile - der
        // Laufend-Indikator (die Pünktchen unten) soll NICHT mitskalieren,
        // wenn tile gehovert wird. scale wirkt auf ALLE Kinder eines Items,
        // ein Punkt, der per anchors relativ zum unteren Rand positioniert
        // ist, würde beim Hochskalieren sichtbar mit wegwandern (die
        // Kachel wächst symmetrisch um ihre Mitte, der Rand rutscht mit).
        // Getrennt bleibt der Punkt exakt an seiner Position stehen.
        Rectangle {
            id: visualBody
            anchors.fill: parent
            radius: Theme.metrics.radius * 0.75
            color: tile.hovered ? Theme.colors.border : "transparent"
            scale: tile.hovered ? 1.15 : 1.0
            opacity: tile.running ? 1.0 : 0.55

            Behavior on color { ColorAnimation { duration: Theme.animationDurations.short } }
            Behavior on scale { NumberAnimation { duration: Theme.animationDurations.short; easing.type: Easing.OutBack } }
            // Bewusst KEINE Behavior on opacity: MorphContent setzt beim Pop-in
            // `opacity = 0` imperativ - das würde eine hier laufende Behavior
            // ALS EIGENE Animation zurück Richtung 0 anfeuern, parallel zu
            // MorphContents eigenem Hochfaden auf 1. Beide Animationen liefen
            // dann gleichzeitig auf derselben Property - wer zuletzt schreibt,
            // gewinnt, rein zufällig je nach Timing. Bei den ersten paar
            // Kacheln (kürzeste Stagger-Verzögerung) gewann das regelmäßig die
            // Behavior, die Kachel blieb unsichtbar - genau der "erste 3 Icons
            // verschwinden wieder" Bug. Ohnehin nutzlos: die Bindung oben wird
            // beim allerersten Pop-in sowieso dauerhaft gekappt (imperative
            // Zuweisung überschreibt QML-Bindings), ein sanfter Fade für
            // spätere running-Wechsel hätte also nie mehr gegriffen.

            IconImage {
                anchors.centerIn: parent
                implicitSize: dockRoot.iconSize
                // IconImage rastert intern bei genau implicitSize (sourceSize
                // = eigene Item-Größe) - beim Hover skaliert visualBody (siehe
                // oben) inkl. Icon per GPU-Transform um 15% hoch, eine bei nur
                // 24px gerasterte Textur sah dabei beobachtbar verwaschen aus.
                // Über backer (Escape-Hatch auf die echte Image dahinter,
                // siehe IconImage-Doku) bewusst mit Reserve nach oben rastern
                // lassen - kostet für die durchgehend Vektor-Icons hier
                // praktisch nichts, bleibt aber auch hochskaliert scharf.
                backer.sourceSize: Qt.size(dockRoot.iconSize * 3, dockRoot.iconSize * 3)
                mipmap: true
                source: tile.modelData.icon
                    ? Quickshell.iconPath(tile.modelData.icon, "application-x-executable")
                    : ""
            }
        }

        // Laufend-Indikator - bewusst AUSSERHALB von visualBody (siehe
        // dortiger Kommentar), damit er beim Hover nicht mitwandert.
        Rectangle {
            visible: tile.running
            width: 4
            height: 4
            radius: 2
            color: Theme.colors.accent
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -6
        }

        // Mehrere Instanzen -> mehrere Pünktchen statt einem
        Row {
            visible: tile.modelData.toplevels.length > 1
            spacing: 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -6
            Repeater {
                model: Math.min(tile.modelData.toplevels.length, 4)
                delegate: Rectangle {
                    width: 4; height: 4; radius: 2
                    color: Theme.colors.accent
                }
            }
        }

        HoverHandler { id: iconHover }

        // Eigenes, simples Item statt QtQuick.Controls ToolTip - ein
        // QQC2-Popup positioniert sich normalerweise relativ zu einem
        // Overlay, das eine ApplicationWindow braucht (hier gibt's nur
        // ein PanelWindow); x/y-Änderungen daran hatten hier beobachtbar
        // KEINEN Effekt mehr. Gleiches Muster wie PopupMenu.qml (dort aus
        // demselben Grund schon so gelöst): normales Item mit direktem
        // x/y, dadurch garantiert vorhersehbar positioniert.
        //
        // parent: view.popupLayer statt einfach Kind von tile zu bleiben -
        // tile steckt in der Pillen-Fläche mit clip:true (siehe
        // MorphContainer.qml), das hätte den Tooltip trotz korrektem x/y
        // abgeschnitten. popupLayer liegt außerhalb dieses Clips.
        Rectangle {
            id: tooltip
            parent: view.popupLayer
            visible: tile.tooltipReady
            z: 100
            width: tooltipLabel.implicitWidth + 16
            height: tooltipLabel.implicitHeight + 10
            radius: 8
            color: Theme.colors.surface
            border.width: 1
            border.color: Theme.colors.borderSurface

            // tile liegt jetzt in einer ANDEREN Koordinaten-Ebene
            // (popupLayer) - Position über mapToItem aus tiles eigenem
            // Koordinatensystem übersetzen. NICHT als reaktive Bindung
            // (wie vorher versucht) - mapToItem() ist ein Funktionsaufruf,
            // QML trackt daraus nur die NAMENTLICH gelesenen Properties
            // (hier: tile.width) als Abhängigkeit, nicht die gesamte
            // Transform-Kette der Vorfahren (RowLayout-Reflow, Dock-Öffnen-
            // Animation, ...) - das Ergebnis blieb dadurch auf einem
            // veralteten Stand hängen, sobald sich irgendwas AUSSER
            // tile.width änderte. Stattdessen einmalig, GENAU im Moment des
            // Sichtbarwerdens neu berechnen (siehe onTooltipReadyChanged
            // oben) - zu dem Zeitpunkt ist die Position sicher aktuell,
            // und während des Hovers bewegt sich der Dock ohnehin nicht.
            function reposition() {
                const anchor = tile.mapToItem(view.popupLayer, tile.width / 2, 0)
                tooltip.x = anchor.x - tooltip.width / 2
                tooltip.y = anchor.y - tooltip.height - 10
            }

            Text {
                id: tooltipLabel
                anchors.centerIn: parent
                text: tile.modelData.name
                color: Theme.colors.text
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 2
            }
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            // Beim Draggen soll der normale Klick (aktivieren/starten)
            // nicht mehr auslösen, sobald tatsächlich gezogen wurde.
            enabled: !dragHandler.active
            onTapped: Services.Windows.handleClick(tile.modelData)
        }

        // Verschieben angepinnter Apps per Drag (unpinnte/laufende Apps
        // sind nicht sortierbar - ihre Reihenfolge kommt einfach aus der
        // Entdeckungsreihenfolge der Fenster, da gibt's nichts Stabiles
        // zum Persistieren). DragHandler statt MouseArea+drag.target, weil
        // es sich mit den TapHandlern hier (gleiche Pointer-Handler-
        // Familie) sauber die Grab-Arbitrierung teilt, statt sie ihr
        // exklusiv wegzunehmen. Während des Drags ändert sich nichts an
        // Favorites (kein Live-Resort mitten im Ziehen - das würde das
        // RowLayout mitten in der Bewegung neu aufbauen und den Drag
        // kaputt machen); erst wenn der Drag ENDET wird die Zielposition
        // aus der finalen x-Position unter den angepinnten Geschwistern
        // berechnet und einmalig committet.
        DragHandler {
            id: dragHandler
            target: tile
            enabled: tile.modelData.pinned
            yAxis.enabled: false
            cursorShape: tile.modelData.pinned ? Qt.OpenHandCursor : Qt.ArrowCursor

            onActiveChanged: {
                if (active || !tile.modelData.desktopEntry) return
                const myCenter = tile.x + tile.width / 2
                let newIndex = 0
                for (const sibling of rowLayout.children) {
                    if (sibling === tile) continue
                    if (!sibling.modelData || !sibling.modelData.pinned) continue
                    if ((sibling.x + sibling.width / 2) < myCenter) newIndex++
                }
                Services.Favorites.moveToIndex(tile.modelData.desktopEntry.id, newIndex)
            }
        }

        // Mittelklick: neue Instanz starten, auch wenn schon welche
        // laufen (üblich bei Terminals/Browsern) - nur sinnvoll mit
        // aufgelöstem DesktopEntry.
        TapHandler {
            acceptedButtons: Qt.MiddleButton
            enabled: tile.modelData.desktopEntry !== null
            onTapped: Services.Windows.launch(tile.modelData)
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: eventPoint => {
                const entries = [];
                if (tile.modelData.desktopEntry) {
                    entries.push({
                        label: tile.modelData.pinned ? Localization.dock.unpin : Localization.dock.pin,
                        icon: tile.modelData.pinned ? "pin-off" : "pin",
                        action: () => Services.Windows.togglePin(tile.modelData)
                    });
                }
                if (tile.running) {
                    entries.push({
                        label: Localization.dock.close,
                        icon: "x",
                        action: () => Services.Windows.closeEntry(tile.modelData)
                    });
                }
                if (entries.length > 0) {
                    // In popupLayer statt view - siehe contextMenu-Deklaration
                    // unten und Tooltip weiter oben für den Grund (clip:true
                    // auf der Pillen-Fläche).
                    const p = tile.mapToItem(view.popupLayer, eventPoint.position.x, eventPoint.position.y);
                    contextMenu.openAt(p.x, p.y, entries);
                }
            }
        }
    }

    // Trennlinie zwischen den Gruppen - Inline-Component, an zwei Stellen
    // gebraucht (zwischen Angepinnt/Laufend und vorm Launcher-Icon).
    component GroupDivider: Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: dockRoot.iconBoxSize * 0.6
        Layout.alignment: Qt.AlignVCenter
        color: Theme.colors.borderSurface
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: Theme.metrics.spacing

        // --- Gruppe 1: Angepinnt (ob laufend oder nicht) ---
        Repeater {
            model: Services.Windows.pinnedEntries
            delegate: DockTile {}
        }

        GroupDivider {
            visible: Services.Windows.pinnedEntries.length > 0
                && Services.Windows.unpinnedRunningEntries.length > 0
        }

        // --- Gruppe 2: Läuft, aber nicht angepinnt ---
        Repeater {
            model: Services.Windows.unpinnedRunningEntries
            delegate: DockTile {}
        }

        GroupDivider {
            visible: Services.Windows.dockEntries.length > 0
        }

        // --- AppLauncher: eigenes Icon, kein System-App ---
        Rectangle {
            id: launcherTile
            property bool hovered: launcherHover.hovered

            Layout.preferredWidth: dockRoot.iconBoxSize
            Layout.preferredHeight: dockRoot.iconBoxSize
            Layout.alignment: Qt.AlignBottom
            radius: Theme.metrics.radius * 0.75
            color: hovered ? Theme.colors.border : "transparent"
            scale: hovered ? 1.15 : 1.0

            Behavior on color { ColorAnimation { duration: Theme.animationDurations.short } }
            Behavior on scale { NumberAnimation { duration: Theme.animationDurations.short; easing.type: Easing.OutBack } }

            // Eigenes 3x3-Punkte-Raster statt eines Theme-Icons - das
            // Theme-SVG (view-app-grid-symbolic) fasst alle 9 Punkte in
            // EINEM einzigen Pfad zusammen, einzeln einfärben würde das
            // Zerlegen des Pfads in 9 Teilstücke brauchen (fragil, an genau
            // dieses eine SVG gebunden). Native Rectangles sind robuster
            // UND bunt - jeder Punkt eine andere Theme-Farbe statt
            // einheitlichem Grau/Akzent, wie gewünscht.
            Grid {
                anchors.centerIn: parent
                columns: 3
                rows: 3
                spacing: dockRoot.iconSize * 0.12
                readonly property real dotSize: dockRoot.iconSize * 0.22
                readonly property var dotColors: [
                    Theme.colors.accent, Theme.colors.info, Theme.colors.accentSoft,
                    Theme.colors.success, Theme.colors.warning, Theme.colors.error,
                    Theme.colors.info, Theme.colors.accentSoft, Theme.colors.accent
                ]

                Repeater {
                    model: 9
                    delegate: Rectangle {
                        required property int index
                        width: parent.dotSize
                        height: parent.dotSize
                        radius: width / 2
                        color: parent.dotColors[index]
                    }
                }
            }

            HoverHandler { id: launcherHover }

            TapHandler { onTapped: LauncherState.toggle() }
        }
    }

    // In popupLayer statt hier in view - view sitzt in der Pillen-Fläche
    // mit clip:true (siehe MorphContainer.qml), das hätte das Menü
    // abgeschnitten, sobald es über die Pille hinausragt (>2 Einträge).
    // popupLayer liegt außerhalb dieses Clips.
    PopupMenu { id: contextMenu; parent: view.popupLayer }
}
