import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../services" as Services

// OSD-Popup für Lautstärke/Helligkeit-Änderungen UND welche Hyprland-
// Submap gerade aktiv ist (siehe services/Osd.qml für die
// Zustandslogik/Trigger). Gleiches Architektur-Muster wie
// PolkitOverlay.qml: EINZELNES, global instanziiertes Fenster (siehe
// shell.qml, kein Variants/Quickshell.screens) statt einer View pro
// Bildschirm - kein `screen:`-Binding, Quickshell platziert das Fenster
// dadurch von sich aus auf dem gerade compositor-fokussierten Monitor.
//
// Rein informativ, bekommt NIE Tastaturfokus (anders als PolkitOverlay) -
// WlrKeyboardFocus.None die ganze Zeit, keine Interaktion nötig/möglich.
// Oben rechts statt oben-mittig verankert, damit es sich nicht mit der
// Dynamic Island (oben mittig) überlappt.
//
// Bewusst flach statt als Karte wie PolkitOverlay/AppLauncher: kein
// border, Icon/Text/Bar alle auf derselbe Höhe gebracht (contentSize
// unten, eine einzige Stelle statt Icon/Text/Bar unabhängig voneinander
// zu dimensionieren) - keins der drei soll optisch "führen". Schatten
// über mehrere gestapelte, halbtransparente Rectangles simuliert (siehe
// shadowLayers unten) statt eines echten Blur-Shaders (Qt5Compat.
// GraphicalEffects/DropShadow) - dieses Projekt vermeidet Shader-Effekte
// bewusst (siehe LucideIcon.qml: unzuverlässig auf manchen Setups).
Scope {
    id: root

    readonly property string channel: Services.Osd.channel
    readonly property bool isSubmap: root.channel === "submap"

    // Icon, Text UND Bar teilen sich diese eine Höhe (siehe Kopfkommentar)
    // - ändert man sie, bleiben alle drei automatisch im Gleichgewicht.
    readonly property int contentSize: 12

    // Bar-Füllstand 0..1 für Lautstärke/Helligkeit - bei Lautstärke über
    // 100% (PipeWire-Überverstärkung, siehe ControlCenterView.qml für
    // dieselbe Kappung) auf 100% gedeckelt, sonst liefe der Fill optisch
    // über den Track hinaus.
    readonly property real level: {
        if (root.channel === "volume") return Math.min(1, Services.Audio.volume)
        if (root.channel === "brightness") return Services.Brightness.percentage
        return 0
    }

    readonly property string iconName: {
        if (root.channel === "volume") return Services.Audio.iconName
        if (root.channel === "brightness") return Services.Brightness.iconName
        return "layers"
    }

    readonly property string submapLabel: Localization.osd.submapNames[Services.Osd.submapName] || Services.Osd.submapName

    PanelWindow {
        id: window

        // Muss Platz für den Schatten reservieren (ragt über die Karte
        // hinaus) - sonst schneidet die Fenstergrenze ihn ab. shadowPad
        // deckt den größten Schatten-Layer (siehe shadowLayers) plus
        // etwas Reserve.
        readonly property int shadowPad: 40

        visible: root.channel !== ""
        color: "transparent"
        exclusiveZone: 0

        anchors { top: true; right: true }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell:osd"

        implicitWidth: card.width + shadowPad
        implicitHeight: card.height + shadowPad

        // Schatten UND Karte sitzen zentriert in diesem Puffer-Bereich -
        // der eigentliche Versatz zur Bildschirmecke kommt komplett aus
        // shadowPad oben, keine zusätzlichen PanelWindow-margins nötig.
        Repeater {
            model: 4

            delegate: Rectangle {
                id: shadowLayer
                required property int index

                anchors.centerIn: card
                width: card.width + (index + 1) * 8
                height: card.height + (index + 1) * 8
                radius: card.radius + (index + 1) * 4
                color: "black"
                opacity: 0.10 - index * 0.02
            }
        }

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: contentRow.implicitWidth + 24
            height: contentRow.implicitHeight + 24
            radius: 10
            color: "black"

            Behavior on width { NumberAnimation { duration: Theme.animationDurations.short } }

            RowLayout {
                id: contentRow
                anchors.centerIn: parent
                spacing: 8

                LucideIcon {
                    name: root.iconName
                    size: root.contentSize
                    color: "white"
                }

                // Submap-Name statt Bar - "wie voll" ergibt für einen
                // Modus-Wechsel keinen Sinn, nur EINES von beiden ist
                // gleichzeitig sichtbar (siehe card-Größe oben).
                Text {
                    visible: root.isSubmap
                    text: root.submapLabel
                    color: "white"
                    font.family: Theme.font.family
                    font.pixelSize: root.contentSize
                    font.bold: true
                }

                Rectangle {
                    id: bar
                    visible: !root.isSubmap
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: root.contentSize
                    radius: height / 2
                    color: Theme.colors.surface

                    Rectangle {
                        width: parent.width * root.level
                        height: parent.height
                        radius: parent.radius
                        color: "white"

                        Behavior on width { NumberAnimation { duration: Theme.animationDurations.short } }
                    }
                }

                Text {
                    visible: !root.isSubmap
                    text: Math.round(root.level * 100) + Localization.common.percent
                    color: "white"
                    font.family: Theme.font.family
                    font.pixelSize: root.contentSize
                }
            }
        }
    }
}
