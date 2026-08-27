import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../widgets" as Widgets
import "../../.."
import "../../../services" as Services

// Control Center: Quick-Toggles + Slider auf Basis der bestehenden Services,
// plus eine gemeinsame Icon-Zeile für Fokus/Nachtlicht UND Shortcuts zu
// weiteren Insel-Ansichten (Timer, Workspaces, ...) - beides "kleine,
// sofortige Aktionen" in derselben Optik, deshalb eine Zeile statt zwei.
// Neuer Icon-Toggle/Shortcut = ein weiterer Eintrag im "quickActions"-Model
// unten. Angelehnt an das Control-Center-Panel von
// https://github.com/corecathx/whisker (Toggle-Kacheln, Slider-Header,
// Contribution-Heatmap).
MorphItem {
    id: view

    name: "controlcenter"
    preferredWidth: 440
    // War 405 - ThemedSlider ist seit dessen Redesign (vast-shell-Optik,
    // an die 34px hohen Icon-MenuButtons angeglichen) 34px statt 16px
    // hoch (implicitHeight: trackHeight + trackSizeDiff), zwei Stück
    // (Lautstärke/Helligkeit) macht +36 insgesamt. Nochmal +58 für die
    // zweite Text-Button-Zeile (VPN/Audioquelle, 44px hoch + ein
    // zusätzlicher 14px-Spacing-Abstand der ColumnLayout).
    preferredHeight: 405 + 2 * 18 + 58

    required property var islandRoot

    // Fokus auf die View selbst erteilt dem Fenster überhaupt erst
    // Tastaturfokus (WlrKeyboardFocus.OnDemand, siehe IslandRoot.qml) -
    // Tab springt danach zum ersten Button (siehe MorphContainer.qml).
    onActiveChanged: if (view.active) view.forceActiveFocus()

    readonly property var quickActionLabels: ({
        dnd: Localization.controlCenter.doNotDisturb, clipboard: Localization.controlCenter.clipboard,
        wallpaper: Localization.controlCenter.wallpaper, powermenu: Localization.controlCenter.powerMenu
    })

    // Toggles (dnd) schalten direkt um; die Shortcuts öffnen eine andere
    // View. Beide teilen sich Icon-Größe/Optik - das war der Punkt.
    // Nachtlicht ist raus (Services.NightLight.qml selbst bleibt, nur der
    // UI-Zugang hier weg). GitHub-Shortcut ist raus, hat seinen eigenen
    // eingebetteten Graph weiter unten (siehe GithubHeatmap), der Shortcut
    // zur eigenen View war dadurch redundant. "calendar" (CalendarView-
    // Stub) ist komplett raus - unbenutzter Stub, siehe shell.qml/
    // IslandShape.qml. "powermenu" ist neu dazugekommen - war vorher ein
    // eigener Button in InfoView.qml, InfoView hat jetzt nur noch den
    // normalen ViewHeader (Akku/Verbindung + Schließen). VPN/Audioquelle
    // sind NICHT hier drin - die haben mehr Gewicht (eigene Text-Button-
    // Zeile wie WLAN/Bluetooth, siehe unten) statt kleiner Icon-Kacheln.
    readonly property var quickActions: [
        { id: "dnd",         icon: "bell-off",       active: Services.Notifications.doNotDisturb, kind: "toggle" },
        { id: "clipboard",   icon: "clipboard-list", active: view.islandRoot.viewMode === "clipboard", kind: "view" },
        { id: "wallpaper",   icon: "wallpaper",     active: view.islandRoot.viewMode === "wallpaper", kind: "view" },
        { id: "powermenu",   icon: "power",         active: view.islandRoot.viewMode === "powermenu", kind: "view" }
    ]

    function runQuickAction(id, kind) {
        if (id === "dnd") Services.Notifications.toggleDnd();
        else view.islandRoot.openView(id);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 14

        ViewHeader { islandRoot: view.islandRoot }

        // WLAN/Bluetooth als Text-Buttons (mehr Gewicht - Verbindungen sind
        // die "wichtigeren" Toggles). Öffnen jetzt jeweils eine eigene View
        // (WifiView/BluetoothView) statt direkt zu toggeln - dort ausbaubar
        // (Netzwerkliste, Geräteliste, ...). `active` trackt weiterhin den
        // echten An/Aus-Zustand (z.B. für spätere Nutzung anderswo), wirkt
        // sich dank `showActiveState: false` aber NICHT mehr aufs Styling
        // aus (siehe MenuButton.qml) - sonst sähe dieser Button, sobald
        // WLAN/Bluetooth an ist, mit gefülltem Akzent-Hintergrund aus der
        // Reihe der übrigen, gleich gewichteten Text-Buttons (VPN/
        // Audioquelle) unten.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MenuButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.preferredHeight: 44
                showLabel: true
                label: Localization.controlCenter.wifiLabel
                active: Services.Network.wifiEnabled
                showActiveState: false
                tooltip: Localization.controlCenter.wifiTooltip
                onTapped: view.islandRoot.openView("wifi")
            }
            MenuButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.preferredHeight: 44
                showLabel: true
                label: Localization.controlCenter.bluetoothLabel
                active: Services.Bluetooth.enabled
                showActiveState: false
                available: Services.Bluetooth.available
                tooltip: Localization.controlCenter.bluetoothTooltip
                onTapped: view.islandRoot.openView("bluetooth")
            }
        }

        // Gleiche Optik/Gewicht wie die WLAN/Bluetooth-Zeile oben, eigene
        // Zeile statt in den kleinen Icon-Kacheln unten - "active" ist
        // hier kein An/Aus-Zustand (ein Audiogerät ist immer "da", VPN
        // hat mehrere Profile), sondern schlicht "ist die jeweilige View
        // gerade offen", damit die Buttons trotzdem sichtbar auf Hover/
        // Tap reagieren wie ihre Vorbilder.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MenuButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.preferredHeight: 44
                showLabel: true
                label: Localization.controlCenter.vpn
                active: view.islandRoot.viewMode === "vpn"
                // Noch deaktiviert - VpnView.qml/services/Vpn.qml sind
                // bewusst noch Mock (siehe dortiger Kommentar), bis klar
                // ist, welche VPN-Clients konkret unterstützt werden
                // sollen. Button ist schon an seinem finalen Platz
                // sichtbar, aber nicht antippbar (MenuButtons `available`
                // dimmt + deaktiviert TapHandler/Fokus, dasselbe Muster
                // wie Services.Bluetooth.available beim Bluetooth-Button).
                available: false
                tooltip: Localization.controlCenter.vpnTooltip
                onTapped: view.islandRoot.openView("vpn")
            }
            MenuButton {
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.preferredHeight: 44
                showLabel: true
                label: Localization.controlCenter.audioSource
                active: view.islandRoot.viewMode === "audiosource"
                tooltip: Localization.controlCenter.audioSourceTooltip
                onTapped: view.islandRoot.openView("audiosource")
            }
        }

        // Fokus/Nachtlicht + View-Shortcuts, eine gemeinsame Zeile kleiner
        // Icon-Buttons (gleiche Optik wie vorher nur die Shortcuts hatten).
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Repeater {
                model: view.quickActions

                delegate: MenuButton {
                    required property var modelData
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34

                    icon: modelData.icon
                    iconSize: 16
                    active: modelData.active
                    available: modelData.available !== false
                    tooltip: view.quickActionLabels[modelData.id] || ""
                    onTapped: view.runQuickAction(modelData.id, modelData.kind)
                }
            }

            Item { Layout.fillWidth: true }
        }

        Divider {}

        // --- Lautstärke ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: Localization.controlCenter.volume
                    color: Theme.colors.text
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.size - 1
                    Layout.fillWidth: true

                    TapHandler { onTapped: Services.Audio.toggleMute() }
                }
                Text {
                    // Services.Audio.volume kann über 1.0 liegen (PipeWire
                    // erlaubt Überverstärkung, z.B. per Medientaste über
                    // 100% hinaus) - hier UND im Slider unten auf 100%
                    // gekappt, statt "200%" anzuzeigen bzw. den Slider-
                    // Füllstand über den Track hinauslaufen zu lassen. Die
                    // tatsächliche Systemlautstärke bleibt davon unberührt,
                    // das ist nur die Anzeige/Bedienung hier.
                    text: Math.round(Math.min(1, Services.Audio.volume) * 100) + Localization.common.percent
                    color: Theme.colors.textMuted
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.size - 2
                }
            }
            ThemedSlider {
                Layout.fillWidth: true
                from: 0
                to: 1
                value: Math.min(1, Services.Audio.volume)
                onMoved: Services.Audio.setVolume(value)
            }
        }

        // --- Helligkeit ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            opacity: Services.Brightness.available ? 1.0 : 0.4
            enabled: Services.Brightness.available

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: Localization.controlCenter.brightness
                    color: Theme.colors.text
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.size - 1
                    Layout.fillWidth: true
                }
                Text {
                    text: Services.Brightness.label
                    color: Theme.colors.textMuted
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.size - 2
                }
            }
            ThemedSlider {
                Layout.fillWidth: true
                from: 0
                to: 1
                value: Services.Brightness.percentage
                onMoved: Services.Brightness.setPercentage(value)
            }
        }

        Divider {}

        Widgets.GithubHeatmap {
            Layout.fillWidth: true
        }
    }
}
