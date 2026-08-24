import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../widgets" as Widgets
import "../../.."
import "../../../services" as Services

// Transformation der Insel beim Eintreffen einer neuen Notification
// (siehe IslandRoot.qml: Connections auf Services.Notifications.latest).
MorphItem {
    id: view

    name: "notify"
    preferredWidth: 380
    preferredHeight: 76

    required property var islandRoot

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // Cover Art der Notification (z.B. Absender-Avatar bei Discord),
        // falls vorhanden - sonst die alte Glocke als Fallback-Icon.
        // Gleiche Komponente wie NotificationCard in InfoView.qml, siehe
        // dortiger/RoundedCover.qml Kommentar.
        Widgets.RoundedCover {
            Layout.alignment: Qt.AlignVCenter
            size: 40
            radius: 10
            fallbackIcon: "bell-ring"
            fallbackIconColor: Theme.colors.accent
            source: Services.Notifications.latest ? Services.Notifications.latest.image : ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: Services.Notifications.latest ? Services.Notifications.latest.appName : ""
                color: Theme.colors.textMuted
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 2
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: Services.Notifications.latest ? Services.Notifications.latest.summary : ""
                color: Theme.colors.text
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: Services.Notifications.latest ? Services.Notifications.latest.body : ""
                color: Theme.colors.textMuted
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 1
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        ActionButton {
            icon: "x"
            iconSize: 14
            diameter: 22
            Layout.alignment: Qt.AlignTop

            onTapped: {
                if (Services.Notifications.latest) Services.Notifications.dismiss(Services.Notifications.latest)
                view.islandRoot.forceReveal = false
                view.islandRoot.closeView()
                view.islandRoot.updateVisibility()
            }
        }
    }
}
