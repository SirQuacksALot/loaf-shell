import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../.."
import "../../../services" as Services

// Geräteauswahl für Standard-Ausgabe (Sink) UND Standard-Eingabe
// (Source/Mikro) - beides ist dieselbe Aktion (ein Pipewire-Gerät als
// "preferred default" markieren, siehe services/Audio.qml), nur für zwei
// verschiedene Geräteklassen. Deshalb eine View mit zwei nebeneinander
// liegenden Listen statt zwei getrennter Views - spürbar breiter als
// WifiView/BluetoothView (eine Spalte je Geräteklasse statt einer
// einzigen scrollbaren Liste).
MorphItem {
    id: view

    name: "audiosource"
    preferredWidth: 560
    preferredHeight: 360

    required property var islandRoot

    onActiveChanged: if (view.active) outputColumn.list.forceActiveFocus()

    // "output"/"input" statt die passende Service-Funktion direkt als
    // Property durchzureichen - gleiches Dispatch-Muster wie
    // PowerMenuView.qml (view.run(id)), damit Zeile/Spalte selbst nichts
    // über Services.Audio wissen müssen.
    function activate(kind, node) {
        if (kind === "output") Services.Audio.setDefaultOutput(node)
        else Services.Audio.setDefaultInput(node)
    }

    // Eine Geräte-Zeile - Icon + Name + Häkchen bei aktuellem Default,
    // Tap setzt das Gerät als Default. Kein Verbinden/Trennen/Vergessen
    // wie bei Wifi/Bluetooth - ein Audiogerät ist immer "da", man wählt
    // nur, welches gerade Standard ist.
    //
    // fitContent (umbrechender statt abgeschnittener Name) ist hier
    // wichtig, nicht nur Kosmetik: mehrere Sinks/Sources derselben
    // Soundkarte teilen sich oft einen langen gemeinsamen Präfix (z.B.
    // "Alder Lake Smart Sound Technology Audio Controller Speaker" vs.
    // "... HDMI / DisplayPort 1/2/3 Output") - bei einzeiligem elide
    // frisst der Präfix die ganze Breite und genau der unterscheidende
    // Teil verschwindet, mehrere echte Geräte sehen dann wie ein
    // einziges, x-fach aufgelistetes aus.
    component DeviceRow: ListCard {
        id: row
        required property var node
        required property bool isDefault
        required property string icon
        required property string kind
        property bool current: false
        // Kein Layout.fillWidth - DeviceRow ist NUR ListView-Delegate
        // (width kommt von dort, siehe unten), nie Kind eines Layouts.
        fitContent: true
        selected: row.isDefault || row.current

        LucideIcon {
            name: row.icon
            size: 16
            color: row.isDefault ? Theme.colors.accent : Theme.colors.textMuted
        }

        // Loader statt Text direkt als RowLayout-Kind - exakt dasselbe
        // Muster wie ClipboardView.qml (dortiger Kommentar). Ein Text mit
        // `Layout.fillWidth` UND `wrapMode: Wrap` direkt im RowLayout
        // steckt in einem Henne-Ei-Problem: die implicitHeight (die
        // ListCards fitContent für die Kartenhöhe braucht) wird VOR der
        // eigentlichen Breitenzuweisung berechnet, kennt die tatsächlich
        // gewrappte Höhe an dem Punkt also noch gar nicht - Symptom war
        // genau das: maximumLineCount begrenzte den Text zwar korrekt auf
        // 2 Zeilen, die Karte blieb aber auf ~1-Zeilen-Höhe stehen,
        // Zeilen ragten ineinander. Ein simples Item mit manuellem
        // `implicitHeight: label.implicitHeight` verschiebt denselben
        // Zirkelbezug nur eine Ebene (dessen implicitHeight hängt ja
        // wiederum von label.width ab, die erst nach der Größenzuweisung
        // des Items feststeht) - ändert also nichts. Loader dagegen
        // spiegelt implicitWidth/-Height seines geladenen Items nach
        // außen, das ist eingebautes Verhalten genau für diesen Fall.
        Loader {
            Layout.fillWidth: true
            sourceComponent: labelComponent
        }

        Component {
            id: labelComponent
            Text {
                width: parent.width
                text: Services.Audio.labelFor(row.node)
                color: row.isDefault ? Theme.colors.accent : Theme.colors.text
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 1
                font.bold: row.isDefault
                wrapMode: Text.Wrap
                // Deckel gegen unbegrenztes Wachstum bei sehr langen
                // Gerätenamen (siehe labelFor()-Kommentar) - danach "…"
                // statt einer noch höheren Karte.
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        LucideIcon {
            visible: row.isDefault
            name: "check"
            size: 13
            color: Theme.colors.accent
        }

        TapHandler {
            enabled: !row.isDefault
            onTapped: view.activate(row.kind, row.node)
        }
    }

    // Eine Spalte (Ausgabe ODER Eingabe): Beschriftung + scrollbare Liste
    // + "nichts gefunden"-Hinweis. Beide Spalten unten teilen sich diese
    // Struktur, nur Modell/Icon/Default/Kind unterscheiden sich.
    component DeviceColumn: ColumnLayout {
        id: column
        required property string label
        required property var devices
        required property var defaultNode
        required property string icon
        required property string kind
        required property string emptyText
        readonly property alias list: listView

        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        Text {
            text: column.label
            color: Theme.colors.textMuted
            font.family: Theme.font.family
            font.pixelSize: Theme.font.size - 2
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 20
            visible: column.devices.length === 0
            text: column.emptyText
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: Theme.colors.textMuted
            font.family: Theme.font.family
            font.pixelSize: Theme.font.size - 3
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: column.devices
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 100
            // Siehe WifiView.qml für die ausführliche Begründung - ohne
            // das war keine der beiden Listen (Ausgabe/Eingabe) per Tab
            // erreichbar, sobald man einmal zu einem anderen Control
            // weitergesprungen ist (MorphContainer.qmls Tab-Handler
            // traversiert nur Items mit activeFocusOnTab:true).
            activeFocusOnTab: true

            function activateCurrent() {
                const n = column.devices[listView.currentIndex]
                if (n) view.activate(column.kind, n)
            }
            Keys.onReturnPressed: listView.activateCurrent()
            Keys.onEnterPressed: listView.activateCurrent()

            // DeviceRow (ein ListCard) DIREKT als Delegate, kein Wrapper-
            // Item mit anchors.fill drumrum - anders als bei WifiView/
            // BluetoothView, deren Reihen fest 44px hoch bleiben (da ist
            // ein Wrapper unschädlich). Hier ist `fitContent: true`
            // (variable Höhe fürs Text-Wrapping) im Spiel: ListCards
            // eigene Höhen-Bindung (`height: fitContent ? row.
            // implicitHeight + 16 : 44`) wird von einem EXTERN
            // aufgesetzten `anchors.fill: parent` schlicht überschrieben
            // (anchors.fill bindet width/height selbst) - die Karte
            // bliebe dadurch für IMMER auf ihrer allerersten Höhe
            // hängen, egal wie viele Zeilen der Text tatsächlich
            // braucht. Exakt das Symptom, das hier auftrat. Direktes
            // Delegate (wie in ClipboardView.qml) umgeht das: nur
            // `width` kommt von außen, `height` bleibt komplett
            // ListCards eigene Sache.
            delegate: DeviceRow {
                id: deviceRow
                required property var modelData
                required property int index
                width: ListView.view.width
                node: deviceRow.modelData
                isDefault: column.defaultNode !== null && deviceRow.modelData.id === column.defaultNode.id
                icon: column.icon
                kind: column.kind
                current: listView.currentIndex === deviceRow.index
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        // Kein Akku-/Verbindungs-Status hier - bei zwei Spalten
        // nebeneinander wäre er eng gequetscht, außerdem redundant zum
        // Netzwerk-Icon in InfoView.qml (siehe ViewHeader.qml).
        ViewHeader { islandRoot: view.islandRoot; showStatus: false }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            DeviceColumn {
                id: outputColumn
                label: Localization.audioSource.outputsLabel
                devices: Services.Audio.outputs
                defaultNode: Services.Audio.sink
                icon: "volume-2"
                kind: "output"
                emptyText: Localization.audioSource.noOutputs
            }

            Rectangle {
                Layout.fillHeight: true
                width: 1
                color: Theme.colors.borderSurface
                opacity: 0.6
            }

            DeviceColumn {
                id: inputColumn
                label: Localization.audioSource.inputsLabel
                devices: Services.Audio.inputs
                defaultNode: Services.Audio.source
                icon: "mic"
                kind: "input"
                emptyText: Localization.audioSource.noInputs
            }
        }
    }
}
