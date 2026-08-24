import QtQuick
import QtQuick.Layouts
import "../.."

// Dünne Trennlinie zwischen zwei Bereichen innerhalb einer View (z.B.
// zwischen den WLAN/Bluetooth-Buttons und den Quick-Toggles im Control
// Center, oder zwischen dem Musik/Kalender-Block und der Notification-
// Liste in InfoView.qml). War ursprünglich eine inline `component Divider`
// nur in ControlCenterView.qml (dort an fünf Stellen gebraucht) - jetzt an
// zwei Views gebraucht, deshalb hierher gezogen statt an zwei Stellen
// unabhängig zu kopieren.
Rectangle {
    Layout.fillWidth: true
    height: 1
    color: Theme.colors.borderSurface
    opacity: 0.6
}
