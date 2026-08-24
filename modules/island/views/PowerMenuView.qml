import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../.."
import "../../../services" as Services

// Power-Menü: Sperren/Abmelden/Neustart/Herunterfahren. Erreichbar über
// die Power-Quick-Action im Control Center. Alles außer Sperren braucht
// einen zweiten, bestätigenden Klick (Label wechselt kurz auf "Sicher?")
// - das sind schwer/gar nicht rückgängig zu machende Aktionen.
MorphItem {
    id: view

    name: "powermenu"
    preferredWidth: 380
    preferredHeight: 150

    required property var islandRoot

    // Fokus auf die View selbst erteilt dem Fenster überhaupt erst
    // Tastaturfokus - Tab springt danach zum ersten Button (siehe
    // WifiView.qml für die ausführliche Begründung).
    onActiveChanged: if (view.active) view.forceActiveFocus()

    readonly property var actions: [
        { id: "lock",     icon: "lock",      label: Localization.powerMenu.lock,     confirm: false },
        { id: "logout",   icon: "log-out",   label: Localization.powerMenu.logout,   confirm: true },
        { id: "reboot",   icon: "rotate-cw", label: Localization.powerMenu.restart,  confirm: true },
        { id: "shutdown", icon: "power",     label: Localization.powerMenu.shutdown, confirm: true }
    ]

    function isAvailable(id) {
        return id !== "lock" || Services.Power.lockAvailable
    }

    function run(id) {
        if (id === "lock") Services.Power.lock()
        else if (id === "logout") Services.Power.logout()
        else if (id === "reboot") Services.Power.reboot()
        else if (id === "shutdown") Services.Power.shutdown()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        // Reihe quadratischer Icon-Kacheln statt einer vertikalen Liste
        // aus Text-Buttons - vier gleichwertige, sofort erkennbare
        // Aktionen nebeneinander.
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Repeater {
                model: view.actions

                delegate: MenuButton {
                    id: button
                    required property var modelData

                    property bool armed: false

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    icon: button.modelData.icon
                    label: Localization.powerMenu.confirm
                    showLabel: button.armed
                    active: button.armed
                    activeColor: Theme.colors.error
                    available: view.isAvailable(button.modelData.id)
                    tooltip: button.armed ? "" : button.modelData.label

                    Timer {
                        id: disarmTimer
                        interval: 3000
                        onTriggered: button.armed = false
                    }

                    onTapped: {
                        if (!button.modelData.confirm || button.armed) {
                            view.run(button.modelData.id)
                            button.armed = false
                        } else {
                            button.armed = true
                            disarmTimer.restart()
                        }
                    }
                }
            }
        }
    }
}
