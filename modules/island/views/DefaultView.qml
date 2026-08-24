import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../.."
import "../../../services" as Services

// Standardansicht der Insel: nur die Uhr. Erscheint automatisch, sobald
// die Insel gehovert wird (erste Hover-Stufe). Hovert man dann DIESE
// Ansicht selbst, eskaliert IslandRoot.qml automatisch zur InfoView
// (zweite Hover-Stufe, siehe dortiger onContentHoveredChanged-Kommentar) -
// hier ist dafür bewusst kein eigener Code nötig.
//
// Später mal mehr kleine Infos hier unterbringen? Einfach in die
// RowLayout einreihen, Theme.metrics.spacing sorgt für gleichmäßige
// Abstände.
MorphItem {
    id: view

    name: "default"
    preferredWidth: 130
    preferredHeight: Theme.metrics.barHeight

    required property var islandRoot

    RowLayout {
        anchors.centerIn: parent
        spacing: Theme.metrics.spacing * 2

        Text {
            id: clockLabel
            text: Qt.formatDateTime(new Date(), "hh:mm")
            color: Theme.colors.text
            font.family: Theme.font.family
            font.pixelSize: Theme.font.size
            font.weight: Theme.font.weight
            font.letterSpacing: Theme.font.letterSpacing

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clockLabel.text = Qt.formatDateTime(new Date(), "hh:mm")
            }
        }

        // Nur sichtbar, solange ungelesene Notifications getrackt werden -
        // rechts neben der Uhr, damit man auch ohne die Insel zu hovern
        // sieht, dass was reingekommen ist. Gleicher ActionButton wie in
        // InfoView.qml (Badge + Count), nicht nur ein nacktes Icon - soll
        // optisch genau wie die anderen Glocken-Buttons aussehen.
        ActionButton {
            Layout.alignment: Qt.AlignVCenter
            visible: Services.Notifications.count > 0
            icon: Services.Notifications.count > 0 ? "bell-ring" : "bell"
            iconSize: 15
            diameter: 22
            showBackground: false
            badgeCount: Services.Notifications.count
            onTapped: view.islandRoot.showNotifications()
        }
    }
}
