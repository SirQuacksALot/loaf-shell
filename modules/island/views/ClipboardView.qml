import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../.."
import "../../../services" as Services

// Zwischenablage-Verlauf über cliphist (services/Clipboard.qml). Tippen
// auf einen Eintrag setzt ihn wieder als aktuellen Klemmbrett-Inhalt und
// schließt die View - wie bei jedem klassischen Clipboard-Manager (Auswahl
// = fertig, kein zusätzlicher "Bestätigen"-Schritt nötig).
MorphItem {
    id: view

    name: "clipboard"
    preferredWidth: 480  // wie InfoView.qml
    preferredHeight: 360

    required property var islandRoot

    // Fokus auf die Liste (siehe WifiView.qml für die ausführliche
    // Begründung) erteilt dem Fenster überhaupt erst Tastaturfokus UND
    // aktiviert Pfeiltasten-Navigation.
    onActiveChanged: if (view.active) {
        Services.Clipboard.refresh()
        list.forceActiveFocus()
    }

    function activateEntry(entry) {
        if (!entry) return
        Services.Clipboard.copyEntry(entry)
        view.islandRoot.closeView()
    }

    // Leichtes Nachziehen, solange die View offen ist - cliphist füllt
    // sich im Hintergrund über wl-paste --watch, neue Einträge sollen
    // ohne manuelles Schließen/Neuöffnen auftauchen.
    Timer {
        interval: 3000
        repeat: true
        running: view.active
        onTriggered: Services.Clipboard.refresh()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Item { Layout.fillWidth: true }
            // Echter Button (mit Hintergrund-Kachel) statt freistehendem
            // Icon - ohne den ViewHeader drüber (der hatte den Schließen-
            // Button als optischen Anker) wirkte ein reines Icon zu
            // beiläufig für eine destruktive Aktion.
            ActionButton {
                icon: "trash-2"
                iconSize: 13
                diameter: 22
                available: Services.Clipboard.entries.length > 0
                tooltip: Localization.clipboard.clearHistory
                onTapped: Services.Clipboard.wipeAll()
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 20
            visible: !Services.Clipboard.available
            text: Localization.clipboard.notInstalled
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: Theme.colors.textMuted
            font.family: Theme.font.family
            font.pixelSize: Theme.font.size - 2
        }
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 20
            visible: Services.Clipboard.available && Services.Clipboard.entries.length === 0
            text: Localization.clipboard.empty
            horizontalAlignment: Text.AlignHCenter
            color: Theme.colors.textMuted
            font.family: Theme.font.family
            font.pixelSize: Theme.font.size - 2
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: Services.Clipboard.available
            clip: true
            spacing: 4
            model: Services.Clipboard.entries
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 100

            Keys.onReturnPressed: view.activateEntry(Services.Clipboard.entries[list.currentIndex])
            Keys.onEnterPressed: view.activateEntry(Services.Clipboard.entries[list.currentIndex])
            // Entf löscht den gerade per Pfeiltasten ausgewählten Eintrag -
            // Tastatur-Äquivalent zum Hover-Löschen-Icon, ohne dass jeder
            // Eintrag dafür extra fokussierbar sein müsste.
            Keys.onDeletePressed: {
                const entry = Services.Clipboard.entries[list.currentIndex]
                if (entry) Services.Clipboard.deleteEntry(entry)
            }

            // Direkt ListCard als Delegate (kein Wrapper-Item nötig, anders
            // als bei WifiView/BluetoothView - deren NetworkRow/DeviceRow
            // müssen ZUSÄTZLICH noch außerhalb der Liste funktionieren,
            // dieser Eintrag hier nur hier). fitContent statt fester 44px:
            // Text bricht um statt einzeilig zu elidieren (gecappt bei
            // 5000 Zeichen - siehe services/Clipboard.qml - `raw`, also
            // was beim Wiederherstellen tatsächlich kopiert wird, bleibt
            // davon unberührt, immer der volle Inhalt), die Karte wächst
            // dafür mit.
            delegate: ListCard {
                id: card
                required property var modelData
                required property int index
                width: ListView.view.width
                fitContent: true
                // Per Pfeiltasten ausgewählt - hebt die Karte über
                // ListCard.selected farblich hervor (Hintergrund), nicht
                // mehr die Textfarbe (wie bei WifiView.qml/BluetoothView.qml
                // - hier gibt's aber kein Äquivalent zu "verbunden", das
                // die Textfarbe stattdessen übernehmen könnte, bleibt
                // also schlicht neutral).
                selected: list.currentIndex === card.index

                LucideIcon {
                    Layout.alignment: Qt.AlignTop
                    name: card.modelData.isImage ? "image" : "file-text"
                    size: 15
                    color: Theme.colors.textMuted
                }

                Text {
                    Layout.fillWidth: true
                    text: card.modelData.preview
                    wrapMode: Text.Wrap
                    color: Theme.colors.text
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.size - 1
                }

                ActionButton {
                    id: rowAction
                    Layout.alignment: Qt.AlignTop
                    opacity: card.hovered || rowAction.activeFocus ? 1 : 0
                    icon: "trash-2"
                    iconSize: 12
                    diameter: 20
                    showBackground: false
                    tooltip: Localization.clipboard.deleteEntry
                    onTapped: Services.Clipboard.deleteEntry(card.modelData)
                }

                TapHandler {
                    onTapped: view.activateEntry(card.modelData)
                }
            }
        }
    }
}
