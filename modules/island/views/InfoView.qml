import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../widgets" as Widgets
import "../../.."
import "../../../services" as Services

// Erweiterte Info-Ansicht: zweite Hover-Stufe (siehe IslandRoot.qml,
// onContentHoveredChanged) - man hovert zuerst die Insel an (zeigt die
// kleine Default-Uhr), hovert man DIE dann selbst, eskaliert es hierher.
// Oben links ein paar Quick-Info-Icons (Akku, Verbindung), rechts Control-
// Center-/Power-Button, darunter Musik- und Kalender-Widget nebeneinander,
// ganz unten (per Divider abgetrennt) die Notification-Liste - war früher
// eine eigene View (views/list, islandRoot.showNotifications()), jetzt
// fest hier eingebettet, damit man Musik/Kalender/Notifications auf einen
// Blick sieht statt extra umschalten zu müssen. Kein eigener Notification-
// Indikator (Glocke/Badge) mehr in der Quick-Info-Zeile - die Liste steht
// ja direkt darunter, ein zusätzlicher Hinweis wäre doppelt gemoppelt.
// Einzig verbliebener Bell-Trigger ist DefaultView.qml (zeigt "was kam
// rein", schon bevor man überhaupt bis hierher hovert).
MorphItem {
    id: view

    name: "info"
    preferredWidth: 480
    // Nur so hoch wie nötig für die Notification-Liste - ohne
    // Notifications bleibt sie (samt Divider) komplett weg, siehe unten.
    preferredHeight: Services.Notifications.count > 0 ? 330 : 150

    required property var islandRoot

    // Eine einzelne Notification-Karte, inkl. Cover-Art links (Avatar/
    // Vorschaubild, falls die Notification eins mitliefert - z.B. gibt
    // Discord den Absender-Avatar mit). Wiederverwendet für die jeweils
    // oberste (=neueste) Karte eines Stacks, siehe GroupCard-Delegate
    // unten.
    component NotificationCard: ListCard {
        id: card
        required property var notification

        // Anders als WLAN/Bluetooth/Clipboard: hier IMMER eine Fläche,
        // nicht nur bei Hover - siehe alwaysVisible-Kommentar in
        // ListCard.qml (ohne das wirkte die Karte bei nur einer
        // Notification komplett rahmenlos, weil dann auch der dekorative
        // Peek-Rand fehlt).
        alwaysVisible: true

        Widgets.RoundedCover {
            Layout.alignment: Qt.AlignVCenter
            size: 28
            radius: 8
            source: card.notification.image
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: card.notification.summary
                color: Theme.colors.text
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 1
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: card.notification.body
                color: Theme.colors.textMuted
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 2
                elide: Text.ElideRight
            }
        }

        ActionButton {
            icon: "x"
            iconSize: 12
            diameter: 20
            showBackground: false
            tooltip: Localization.info.dismiss
            onTapped: Services.Notifications.dismiss(card.notification)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        ViewHeader { islandRoot: view.islandRoot }

        // --- Musik + Kalender nebeneinander ---
        RowLayout {
            Layout.fillWidth: true
            // Kein Layout.fillHeight mehr - das übernimmt jetzt die
            // Notification-Liste weiter unten, diese Zeile bleibt bei ihrer
            // natürlichen (durch MediaWidget/CalendarWidget vorgegebenen) Höhe.
            // War 24: zusammen mit MediaWidget(210)+CalendarWidget(200) kam
            // die Zeile auf 458px Mindestbreite - 6px mehr als die 452px,
            // die preferredWidth(480) abzüglich der 14px-Margins übrig
            // lässt. Da beide Widgets feste implicitWidth haben (können
            // nicht schrumpfen), lief die GESAMTE Spalte über den rechten
            // Rand hinaus - und zog die obere Zeile (teilt sich dieselbe
            // Spaltenbreite via Layout.fillWidth) gleich mit. Symptom:
            // rechter Rand schmaler als linker, beide Zeilen nicht bündig.
            spacing: 14

            Widgets.MediaWidget {
                Layout.alignment: Qt.AlignVCenter
            }

            // Spacer zwischen statt hinter den Widgets - drückt Media links
            // und Kalender rechtsbündig auseinander (gleiches Muster wie in
            // der Icon-Zeile oben), statt beide links zusammenzudrängen.
            Item { Layout.fillWidth: true }

            Widgets.CalendarWidget {
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // Divider + Liste sind komplett weg, solange es nichts zu zeigen
        // gibt - keine leere Fläche mit nur einem "Keine Benachrichtigungen"
        // drin. preferredHeight oben schrumpft passend mit, sonst bliebe
        // trotzdem eine leere Lücke am unteren Rand stehen.
        Divider { visible: Services.Notifications.count > 0 }

        // --- Notification-Liste ---
        // War früher eine eigene View (views/NotificationListView.qml,
        // Ziel "list") - jetzt fest Teil von InfoView, getrennt per Divider
        // wie im Control Center. Kein eigener Titel mehr über den Karten
        // (wie in allen anderen Views auch, siehe Kopf-Kommentare dort) -
        // nur noch "Alle löschen", rechtsbündig. Fokus-/Pfeiltasten-Navigation
        // ist raus - InfoView wird meist rein passiv per Hover erreicht,
        // ihr dabei jedes Mal aktiv die Tastaturfokus zu klauen wäre
        // aufdringlich (anders als bei bewusst per Klick geöffneten Views
        // wie WifiView, siehe dort).
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            visible: Services.Notifications.count > 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                MenuButton {
                    visible: Services.Notifications.count > 0
                    label: Localization.info.clearAll
                    showLabel: true
                    showBackground: false
                    contentPadding: 0
                    tooltip: Localization.info.clearAllTooltip
                    onTapped: Services.Notifications.clearAll()
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: Services.Notifications.groupedList

                // Eine Gruppe (alle Notifications EINER App) liegt "auf
                // einem Haufen": nur die oberste (= neueste) Karte ist
                // wirklich da, dahinter höchstens 2 blasse, rein
                // dekorative Kanten als Hinweis "hier liegt noch was"
                // (gecappt bei 2, unabhängig von der tatsächlichen
                // Anzahl - mehr wirkt nicht mehr gestapelt, nur
                // unübersichtlich). Kein App-Name, keine separate
                // Kategorie-Anzeige - man sieht/verwirft einfach
                // Notification für Notification. Verwerfen der obersten
                // Karte lässt automatisch die nächstältere nachrücken,
                // weil sich die Gruppe live aus
                // Services.Notifications.groupedList neu berechnet.
                delegate: Item {
                    id: groupCard
                    required property var modelData
                    required property int index
                    width: ListView.view.width

                    readonly property var notifications: groupCard.modelData.notifications
                    readonly property int peekCount: Math.min(groupCard.notifications.length - 1, 2)

                    // Plain Item statt Layout - anders als ColumnLayout/
                    // RowLayout bindet Item seine height NICHT automatisch
                    // an implicitHeight, das müssen wir hier also explizit
                    // selbst tun (sonst bliebe height bei 0, ListView würde
                    // alle Karten übereinander stapeln statt untereinander).
                    height: 44 + groupCard.peekCount * 4

                    Repeater {
                        model: groupCard.peekCount
                        delegate: Rectangle {
                            required property int index
                            anchors.top: parent.top
                            anchors.topMargin: (index + 1) * 4
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: (index + 1) * 6
                            anchors.rightMargin: (index + 1) * 6
                            height: 44
                            radius: 8
                            color: Theme.colors.surface
                            opacity: 0.5 - index * 0.2
                        }
                    }

                    NotificationCard {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        notification: groupCard.notifications[0]
                    }
                }
            }
        }
    }
}
