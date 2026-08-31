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

        // fitContent (Body wrappt statt einzeilig abzuschneiden) statt
        // fixer 44px - siehe AudioSourceView.qml für dieselbe Umstellung.
        // Card bekommt hier NUR anchors.top/left/right von außen (siehe
        // Delegate unten), NIE anchors.bottom/anchors.fill - genau DAS
        // war der eigentliche Bug bei AudioSourceView: ein externes
        // anchors.fill überschreibt ListCards eigene fitContent-Höhen-
        // Bindung komplett, die Karte bliebe sonst für immer auf ihrer
        // allerersten Höhe stehen.
        fitContent: true

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

            // Loader statt Text direkt als ColumnLayout-Kind - exakt
            // dasselbe Muster wie ClipboardView.qml/AudioSourceView.qml
            // (dortige Kommentare für die ausführliche Begründung): ein
            // Text mit Layout.fillWidth UND wrapMode:Wrap kennt seine
            // gewrappte implicitHeight erst NACH der Breitenzuweisung,
            // Loader spiegelt die implizite Größe seines geladenen Items
            // dagegen nach außen.
            Loader {
                Layout.fillWidth: true
                visible: card.notification.body.length > 0
                active: visible
                sourceComponent: bodyComponent
            }

            Component {
                id: bodyComponent
                Text {
                    width: parent.width
                    text: card.notification.body
                    color: Theme.colors.textMuted
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.size - 2
                    wrapMode: Text.Wrap
                    // Deckel gegen ausufernde Kartenhöhe bei sehr langen
                    // Benachrichtigungstexten - danach "…". 3 statt der
                    // 2 in AudioSourceView.qml, Notification-Bodies sind
                    // im Schnitt gehaltvoller als ein Gerätename.
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
            }

            // Action-Buttons für benannte, NICHT-Default-Actions (z.B.
            // "Antworten") - Notification.actions kam bisher NIRGENDS im
            // Code vor, weder im Service-Snapshot noch hier; die Buttons
            // existierten auf DBus-Ebene durchaus, wurden nur nie
            // gerendert. "default" (freedesktop-Konvention: "das passiert
            // bei Klick auf die Notification selbst", siehe Vencords
            // Neustart-Hinweis) blendet der Delegate unten per `visible`
            // selbst aus - dafür gibt's den TapHandler auf der ganzen
            // Karte, ein zusätzlicher Button dafür wäre doppelt gemoppelt.
            //
            // WICHTIG: Repeater.model bekommt die rohe `actions`-Sequenz
            // DIREKT, kein `.filter(...)` mehr davor in einem eigenen
            // Property-Binding. Ursprünglich stand hier
            // `actions.filter(a => a.identifier !== "default")` als
            // readonly property, direkt als Repeater-Model verwendet -
            // das hat beim Öffnen dieser View einen harten Absturz
            // ausgelöst (SIGSEGV/Stack-Overflow in Qts eigener
            // QVariantMap-Konvertierung, während der Repeater neue
            // Delegates anlegt - Crash-Report vom 28.08. bestätigt,
            // Toast/NotifyView.qml mit derselben invokeDefaultAction()-
            // Logik aber OHNE Repeater/.filter() lief dabei fehlerfrei
            // weiter). `.filter()` auf einer QML-Sequenz aus QObject-
            // Zeigern erzeugt bei JEDER Neubewertung ein frisches
            // JS-Array, das der Repeater als komplett neues Model
            // interpretiert - deutlich fragiler als die rohe,
            // eingebaute Sequenz direkt zu nutzen (ein Standard-Pattern,
            // das QML explizit für Repeater.model unterstützt).
            RowLayout {
                id: actionsRow
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: card.notification.notification !== null && card.notification.notification.actions.length > 0
                spacing: 6

                Repeater {
                    model: card.notification.notification ? card.notification.notification.actions : []
                    delegate: MenuButton {
                        required property var modelData
                        // "default" hier ausblenden statt vorher
                        // rauszufiltern (siehe Kommentar oben) - bleibt
                        // dadurch zwar noch Teil des Models (0 Elemente
                        // weniger zum Neuanlegen bei jeder Notification-
                        // Änderung), ist aber der bewusste Kompromiss für
                        // Stabilität.
                        visible: modelData.identifier !== "default"
                        showLabel: true
                        label: modelData.text
                        contentPadding: 10
                        Layout.preferredHeight: 26
                        // Akzentfarbe statt MenuButtons gedämpftem
                        // Standard (siehe dortiger Kommentar) - eine
                        // Notification-Action ist eine echte Aufforderung
                        // zum Handeln, keine beiläufige Option.
                        inactiveContentColor: Theme.colors.accent
                        onTapped: {
                            // Quelle könnte die Notification zwischen
                            // Anzeige und Klick bereits geschlossen haben
                            // (invoke() liefe dann ins Leere) - gleiches
                            // Absicherungsmuster wie bei dismiss() unten.
                            // KEIN automatisches dismiss() danach mehr -
                            // eine Action auszulösen ist ein anderer
                            // Vorgang als die Notification aus der Liste
                            // zu entfernen, das bleibt allein dem
                            // Kreuz-Button vorbehalten (konsistent mit dem
                            // Karten-Tap für die Default-Action unten).
                            try {
                                modelData.invoke();
                            } catch (e) {
                                console.warn("InfoView: Notification-Action konnte nicht ausgeführt werden:", e);
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
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

        // Karte antippen (nicht die Buttons - deren eigene TapHandler
        // konsumieren Taps innerhalb ihrer Fläche zuerst, siehe
        // NotifyView.qml für dieselbe Begründung) löst die "default"-
        // Action aus, falls vorhanden - KEIN dismiss(), die Notification
        // bleibt in der Liste stehen (nur das Kreuz entfernt sie
        // wirklich).
        TapHandler {
            onTapped: Services.Notifications.invokeDefaultAction(card.notification)
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
                    // Reiner Text-Link - bewusst akzentfarben statt
                    // MenuButtons gedämpftem Standard (siehe dortiger
                    // Kommentar), sonst nicht als klickbar erkennbar.
                    inactiveContentColor: Theme.colors.accent
                    tooltip: Localization.info.clearAllTooltip
                    onTapped: Services.Notifications.clearAll()
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                // Echtes ListModel, inkrementell gepflegt (siehe
                // Notifications.qml, groupedModel-Kommentar) - NICHT mehr
                // eine bei jeder Notification komplett neu berechnete
                // var-Property. Grund: genau das hat wiederholt zu
                // SIGSEGV-Abstürzen in Qts QML-Engine geführt, siehe
                // dortiger Kommentar für Details.
                model: Services.Notifications.groupedModel

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
                // weil `notificationIds` als Model-Rolle neu bindet, sobald
                // Notifications.qml diese eine Zeile per setProperty()
                // aktualisiert.
                delegate: Item {
                    id: groupCard
                    // Kommagetrennter String, kein Array - siehe Kommentar
                    // bei Notifications.qml::_addToGroups() (jedes Array als
                    // ListModel-Rolle wird von QML automatisch in ein
                    // eigenes Sub-Model umgewandelt, live bestätigt sowohl
                    // mit Objekten als auch mit simplen Zahlen drin). Hier,
                    // in einer normalen property (keine ListModel-Rolle
                    // mehr), zurück in ein echtes Array parsen. Volle
                    // Notification-Daten kommen per entryById().
                    required property string notificationIds
                    required property int index
                    width: ListView.view.width

                    readonly property var idList: groupCard.notificationIds.split(",").map(Number)

                    readonly property int peekCount: Math.min(groupCard.idList.length - 1, 2)

                    // Plain Item statt Layout - anders als ColumnLayout/
                    // RowLayout bindet Item seine height NICHT automatisch
                    // an implicitHeight, das müssen wir hier also explizit
                    // selbst tun (sonst bliebe height bei 0, ListView würde
                    // alle Karten übereinander stapeln statt untereinander).
                    // Basiert jetzt auf topCard.height statt fest 44 - die
                    // oberste Karte kann dank fitContent (siehe
                    // NotificationCard oben) inzwischen mehrzeilig sein,
                    // ein hartkodierter Wert hätte sonst die NÄCHSTE
                    // Gruppen-Karte überlappt, sobald ein Body umbricht.
                    height: topCard.height + groupCard.peekCount * 4

                    // Die dekorativen Peek-Kanten dahinter - Höhe folgt
                    // ebenfalls topCard.height, sonst passt die Fanning-
                    // Optik (gleiche Höhe, nur nach unten/innen versetzt)
                    // nicht mehr zur tatsächlichen Kartenhöhe.
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
                            height: topCard.height
                            radius: 8
                            color: Theme.colors.surface
                            opacity: 0.5 - index * 0.2
                        }
                    }

                    NotificationCard {
                        id: topCard
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        notification: Services.Notifications.entryById(groupCard.idList[0])
                    }
                }
            }
        }
    }
}
