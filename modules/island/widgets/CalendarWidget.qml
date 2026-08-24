import QtQuick
import QtQuick.Layouts
import "../../.."

// Uhrzeit + ein Wochenstreifen zentriert auf heute (3 Tage davor/danach,
// Wochenenden farblich abgesetzt, weiter entfernte Tage dezent
// ausgeblendet). Angelehnt an
// ~/.config/dotfiles/old/old/widgets/CalendarClockWidget.qml, aber mit
// Theme-Farben statt fest codierten.
Item {
    id: root

    // Wie stark entfernte Tage abgedunkelt werden (0.0 - 1.0, kleiner = dunkler)
    property real fadeMinOpacity: 0.16
    property real fadeStep: 0.22

    readonly property var dayShortLabels: Localization.calendar.dayShortLabels
    readonly property var dayLabels: Localization.calendar.dayLetterLabels
    readonly property date today: new Date()

    implicitWidth: 200
    implicitHeight: clockLabel.implicitHeight + column.spacing + dayRow.implicitHeight

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: 8

        // Rechtsbündig statt zentriert - implicitWidth(200) ist breiter als
        // der eigentliche Inhalt (Uhrzeit/Wochenstreifen), zentriert bliebe
        // dadurch Luft zur rechten Kante. In InfoView.qml steht dieses
        // Widget als letztes Element rechtsbündig in seiner Zeile, direkt
        // unter dem Power-Button - der sollte mit den sichtbaren Pixeln
        // hier fluchten, nicht mit der (breiteren) unsichtbaren Box.
        Text {
            id: clockLabel
            Layout.alignment: Qt.AlignRight
            text: Qt.formatTime(new Date(), "hh:mm")
            color: Theme.colors.text
            font.family: Theme.font.family
            font.pixelSize: 22
            font.weight: Theme.font.weight

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clockLabel.text = Qt.formatTime(new Date(), "hh:mm")
            }
        }

        RowLayout {
            id: dayRow
            Layout.alignment: Qt.AlignRight
            spacing: 10

            Repeater {
                model: 7

                delegate: ColumnLayout {
                    id: dayDelegate
                    required property int index

                    readonly property int offset: index - 3
                    readonly property int dist: Math.abs(offset)
                    readonly property date dateValue: {
                        const d = new Date(root.today)
                        d.setDate(root.today.getDate() + offset)
                        return d
                    }
                    readonly property bool isWeekend: dateValue.getDay() === 0 || dateValue.getDay() === 6
                    readonly property color dayColor: offset === 0
                        ? Theme.colors.text
                        : (dayDelegate.isWeekend ? Theme.colors.error : Theme.colors.textMuted)
                    readonly property real dayOpacity: offset === 0 ? 1 : Math.max(root.fadeMinOpacity, 1 - dist * root.fadeStep)

                    spacing: 2

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: dayDelegate.offset === 0
                            ? root.dayShortLabels[dayDelegate.dateValue.getDay()]
                            : root.dayLabels[dayDelegate.dateValue.getDay()]
                        color: dayDelegate.dayColor
                        opacity: dayDelegate.dayOpacity
                        font.family: Theme.font.family
                        font.pixelSize: dayDelegate.offset === 0 ? 11 : 10
                        font.bold: dayDelegate.offset === 0
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: dayDelegate.dateValue.getDate()
                        color: dayDelegate.dayColor
                        opacity: dayDelegate.dayOpacity
                        font.family: Theme.font.family
                        font.pixelSize: 15
                        font.bold: dayDelegate.offset === 0
                    }
                }
            }
        }
    }
}
