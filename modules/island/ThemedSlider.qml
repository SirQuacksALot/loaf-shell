import QtQuick
import QtQuick.Controls
import ".."
import "../.."

// Einheitlich gestylter Slider - dicker, komplett abgerundeter Balken
// (Track + Fill) statt des Default-Controls-Looks (dünne Linie + separater
// kreisrunder Griff). Optik jetzt komplett an
// https://github.com/myamusashi/vast-shell angelehnt (deren
// StyledSlide.qml, konkret die Verwendung in
// Qml/Modules/Drawers/QuickSettings/Settings/BrightnessControls.qml) -
// ALLE Maße 1:1 von dort übernommen, aus dem Quellcode abgelesen und
// gegen einen Screenshot pixelgenau verifiziert (component height 48,
// trackHeight 48-15=33, handleWidth 4/2, handleGap 6):
//
// - Der Griff ist ein eigenständig eingefärbter, schmaler Balken statt
//   eines Lochs (unsere vorherige, an https://github.com/corecathx/whisker
//   angelehnte Variante) - UND deutlich höher als der Track selbst (volle
//   Komponentenhöhe statt nur trackHeight), durchbricht die Linie dadurch
//   sichtbar nach oben/unten statt bündig darin zu sitzen.
// - Der Fill rundet NUR sein äußeres (linkes) Ende ab - die Seite zum
//   Griff hin bleibt eckig, statt (wie vorher) an beiden Enden zu runden
//   (sonst wirkt der Fill wie eine frei schwebende Pille in der Mitte des
//   Tracks statt wie ein bündig endender Balken).
//
// Der ganze Balken bleibt per Klick/Zug bedienbar (Standardverhalten von
// QtQuick.Controls.Slider bleibt unverändert, nur die Optik ändert sich).
// Zusätzlich von vast-shell übernommen: eine Wert-Bubble während des
// Ziehens (gleiche Optik wie ButtonTooltip.qml), nicht deren zeitversetztes
// Hover-Muster, weil die Bubble sofort mit dem Ziehen erscheinen/mitlaufen
// soll, nicht nach Verzögerung.
Slider {
    id: root

    // trackSizeDiff 1:1 von vast-shell - Höhe der Komponente insgesamt ist
    // trackHeight + trackSizeDiff, damit der Griff (siehe handle: unten,
    // volle Komponentenhöhe) oben/unten symmetrisch über den Track
    // hinausragen kann. trackHeight selbst NICHT mehr 1:1 von dort (war
    // 33) - auf Wunsch stattdessen an die 34px hohen Icon-MenuButtons im
    // Control Center angeglichen (implicitHeight = 19+15 = 34, siehe
    // ControlCenterView.qml/quickActions), nicht an vast-shells eigene
    // (deutlich größere) Slider-Verwendungsstelle.
    property int trackHeight: 19
    property int trackSizeDiff: 15

    // Größe des Griffs - 1:1 von vast-shell übernommen (deren handleSize/
    // handleGap), siehe Kopfkommentar.
    property int handleWidth: 4
    // War 6 (1:1 von vast-shell) - etwas verkleinert auf Wunsch, treibt
    // sowohl den Abstand von fill zum Griff (siehe fill unten) ALS AUCH
    // die Breite von handleGapCut (siehe dort) - beide bleiben dadurch
    // automatisch bündig zueinander, statt hier isoliert nur eines von
    // beiden schmaler zu machen (das hätte einen sichtbaren Spalt/Seam
    // zwischen fill und handleGapCut hinterlassen).
    property int handleGap: 4
    property color handleColor: Theme.colors.accentSoft

    // War height/2 (voller Stadion-/Pillen-Look, wirkte bei trackHeight:33
    // an den Enden zu rund) - proportional mit auf den neuen, kleineren
    // trackHeight (19) runtergerechnet, sonst hätte Qt es hier (>height/2)
    // sowieso wieder auf vollrund gekappt und die Vorgabe "nicht ganz so
    // rund" wäre bei dieser Höhe unbeabsichtigt wieder verschwunden.
    // Gemeinsam für Track UND Fill, damit deren linkes/äußeres Eck
    // weiterhin exakt zusammenpasst (siehe fill unten).
    property int cornerRadius: 6
    // Farbe der Unterbrechung um den Griff (siehe handleGapCut unten) -
    // Hintergrundfarbe der Insel, dieselbe Fläche "schimmert" dadurch quasi
    // durch Fill/Track hindurch, statt dass der Griff nur einen Rahmen
    // bekäme.
    property color handleGapColor: Theme.colors.background

    implicitHeight: root.trackHeight + root.trackSizeDiff

    // Tastaturfokus (Pfeiltasten ändern den Wert dann per Default-Verhalten
    // von QQC2 Slider) - ohne das nie Teil der Tab-Kette, der Fokusring
    // unten also nie sichtbar.
    activeFocusOnTab: true

    // Explizit statt dem Default zu vertrauen (der hängt an
    // Application.styleHints.useHoverEffects, also potenziell
    // Plattform-/Compositor-abhängig) - root.hovered (von Control geerbt)
    // soll hier zuverlässig funktionieren, siehe Hover-Highlight unten.
    hoverEnabled: true

    // Passiver HoverHandler NUR für den Cursor - schnappt sich keinen
    // Pointer-Grab (anders als der interne Slider-Drag), stört daher nicht
    // beim Ziehen. Gleiches Muster wie ActionButton/MenuButton/Toggle,
    // Cursor wechselt zusätzlich während des Ziehens selbst (wie im
    // vast-shell-Vorbild: "zupackende" Faust statt Zeigehand).
    HoverHandler {
        cursorShape: root.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    }

    // Wert-Bubble während des Ziehens - reparentet sich auf das
    // Fenster-Root (gleicher Trick wie ButtonTooltip.qml), um JEDEM
    // clip:true auf dem Weg zu entkommen (die Insel-Fläche selbst clippt,
    // siehe MorphContainer.qml). Position wird bei jeder Änderung von
    // visualPosition/pressed neu berechnet - anders als bei ButtonTooltip
    // (einmalig beim Sichtbarwerden) MUSS die Bubble hier während des
    // gesamten Drags live mitlaufen.
    readonly property Item _popupLayer: root.Window.window ? root.Window.window.contentItem : null

    function _repositionValueBubble() {
        if (!root._popupLayer) return
        const handleCenterX = root.leftPadding + root.visualPosition * root.availableWidth
        const trackTop = root.topPadding + (root.availableHeight - root.trackHeight) / 2
        const pos = root.mapToItem(root._popupLayer, handleCenterX, trackTop)
        valueBubble.x = Math.max(4, Math.min(pos.x - valueBubble.width / 2, root._popupLayer.width - valueBubble.width - 4))
        valueBubble.y = pos.y - valueBubble.height - 8
    }

    onPressedChanged: root._repositionValueBubble()
    onVisualPositionChanged: if (root.pressed) root._repositionValueBubble()

    background: Item {
        id: bg
        x: root.leftPadding
        y: root.topPadding + (root.availableHeight - height) / 2
        width: root.availableWidth
        height: root.trackHeight

        readonly property real handleX: root.visualPosition * width
        readonly property real effectiveHandleWidth: root.pressed ? root.handleWidth * 0.5 : root.handleWidth

        // Wert-Bubble während des Ziehens - als Kind eines gewöhnlichen
        // Item hier statt direkt der Slider-Wurzel deklariert (Control-
        // Templates haben eigene, uneindeutige Regeln dafür, was ein
        // "loses" Kind-Item automatisch wird, z.B. contentItem). `parent:`
        // reparentet sie zur Laufzeit ohnehin sofort auf das Fenster-Root
        // (gleicher Trick wie ButtonTooltip.qml), das hier ist nur der
        // deklarative Ausgangspunkt.
        Rectangle {
            id: valueBubble
            parent: root._popupLayer || root
            visible: root.pressed
            z: 10000
            radius: 6
            color: Theme.colors.surface
            border.width: 1
            border.color: Theme.colors.borderSurface
            width: valueLabel.implicitWidth + 16
            height: valueLabel.implicitHeight + 10

            Text {
                id: valueLabel
                anchors.centerIn: parent
                text: Math.round(root.visualPosition * 100) + Localization.common.percent
                color: Theme.colors.text
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 3
            }

            onVisibleChanged: if (visible) root._repositionValueBubble()
        }

        // Track-Grund (leer) - liegt UNTER Fill/Griff, deckt durchgehend
        // die volle Breite ab (auch dort, wo Fill/Griff bei 0%/100%
        // ausgeblendet sind).
        Rectangle {
            id: track
            anchors.fill: parent
            radius: root.cornerRadius
            color: Theme.colors.surface
        }

        // Fill - endet VOR dem Griff (halbe Griffbreite + handleGap), statt
        // nahtlos bis zu dessen Mitte zu laufen - genau der Abstand, der
        // den Griff als eigenständigen Balken lesbar macht statt ihn im
        // Fill verschwinden zu lassen (siehe vast-shell StyledSlide.qml).
        // NUR das äußere (linke) Ende rundet ab - die Seite zum Griff hin
        // bleibt eckig, sonst wirkt der Fill wie eine frei schwebende
        // Pille statt wie ein bündig endender Balken (siehe Kopfkommentar).
        Rectangle {
            id: fill
            anchors.left: parent.left
            height: parent.height
            topLeftRadius: root.cornerRadius
            bottomLeftRadius: root.cornerRadius
            topRightRadius: 0
            bottomRightRadius: 0
            color: Theme.colors.accent
            width: Math.max(0, bg.handleX - bg.effectiveHandleWidth / 2 - root.handleGap)
        }

        // Hover-Highlight: gleiches Muster wie ActionButton.qml - eigenes,
        // halbtransparentes Rectangle statt Track-/Fill-Farbe selbst
        // umzuschalten. VOR handleGapCut/handleMarker deklariert (=liegt
        // darunter) - sonst würde der Hover-Schimmer die Unterbrechung mit
        // aufhellen und den "hier ist der Balken unterbrochen"-Kontrast
        // beim Hovern verwaschen. So malt handleGapCut ihn an der
        // Griffposition zuverlässig wieder zu, Hover ODER nicht.
        Rectangle {
            anchors.fill: track
            radius: track.radius
            color: "#ffffff"
            opacity: root.hovered ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.animationDurations.short } }
        }

        // Fokusring, nach AUSSEN versetzt statt als Border auf der Track-
        // Fläche selbst (siehe MenuButton.qml für dieselbe Begründung) -
        // bei visualPosition nahe 1 ist die Fläche fast komplett Accent-
        // gefüllt, ein Border in derselben Farbe DARAUF wäre dann größtenteils
        // unsichtbar. VOR handleGapCut/handleMarker deklariert (=liegt
        // darunter), aus demselben Grund wie beim Hover-Highlight oben - der
        // Griff ragt oben/unten weiter raus als der Ring reicht, würde der
        // Ring darüber liegen, würde sein Rand sichtbar quer durch den Griff
        // laufen statt sauber von der Unterbrechung durchbrochen zu werden.
        Rectangle {
            visible: root.activeFocus
            anchors.fill: track
            anchors.margins: -3
            // War height/2 (voller Pillen-Look, unabhängig vom
            // tatsächlichen track/fill-radius) - track.radius + der
            // Versatz durch obige margins:-3, damit die Ecken konzentrisch
            // zu denen von Track/Fill sitzen statt runder zu wirken als der
            // Rest des Sliders.
            radius: track.radius + 3
            color: "transparent"
            border.width: 2
            border.color: Theme.colors.accent
        }

        // Die Unterbrechung um den Griff - liegt ÜBER Fill/Track/Hover-
        // Highlight/Fokusring, ABER UNTER dem Griff selbst (siehe Deklarations-
        // reihenfolge: später deklariert = weiter oben gezeichnet). Malt
        // dadurch alles darunter an dieser Stelle mit Hintergrundfarbe
        // komplett zu, bevor der schmalere Griff mittig darüber sitzt -
        // genau der "Balken ist an dieser Stelle unterbrochen"-Effekt statt
        // nur eines Rahmens auf dem Griff selbst. Breite = Griffbreite +
        // auf JEDER Seite ein handleGap (identisch zu dem Abstand, den fill
        // oben schon zum Griff einhält - deren rechte Kante trifft dadurch
        // nahtlos auf die linke Kante hier). Höhe/y wie beim Griff selbst
        // (volle Komponentenhöhe statt nur trackHeight) - sonst würde der
        // Griff oben/unten über den Rand der Unterbrechung hinausragen.
        Rectangle {
            id: handleGapCut
            visible: root.visualPosition > 0.001 && root.visualPosition < 0.999
            x: bg.handleX - width / 2
            y: (parent.height - height) / 2
            width: bg.effectiveHandleWidth + root.handleGap * 2
            height: root.availableHeight
            radius: 0
            color: root.handleGapColor

            Behavior on width { NumberAnimation { duration: Theme.animationDurations.short } }
        }

        // Der Griff selbst - schmaler, eigenständig eingefärbter Balken,
        // mittig in der Unterbrechung oben, auf VOLLER Komponentenhöhe
        // (nicht nur trackHeight) - ragt dadurch oben/unten sichtbar über
        // den Track hinaus, statt bündig darin zu sitzen. y hier lokal
        // relativ zu bg (trackHeight hoch) berechnet, dadurch automatisch
        // symmetrisch zentriert (negativer Wert = Überstand).
        Rectangle {
            id: handleMarker
            visible: root.visualPosition > 0.001 && root.visualPosition < 0.999
            x: bg.handleX - width / 2
            y: (parent.height - height) / 2
            width: bg.effectiveHandleWidth
            height: root.availableHeight
            radius: width / 2
            color: root.handleColor

            Behavior on width { NumberAnimation { duration: Theme.animationDurations.short } }
        }
    }

    handle: Item {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + (root.availableHeight - height) / 2
        width: root.trackHeight
        height: root.trackHeight
    }
}
