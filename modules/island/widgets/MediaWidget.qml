import QtQuick
import QtQuick.Layouts
import "../.."
import "../../.."
import "../../../services" as Services

// Warum das Cover per Canvas statt "Rectangle { clip: true }" gerundet
// wird: `clip: true` clippt in QtQuick nur auf das rechteckige Bounding-Box
// eines Items, NICHT auf dessen `radius`-Form - ein Bild darin behält also
// eckige Ecken. Der Klassiker dafür ist ein Shader-Effekt (OpacityMask/
// MultiEffect), aber genau die vermeidet dieses Projekt bewusst (siehe
// LucideIcon.qml - unzuverlässig auf manchen Setups). Canvas (Software-
// Renderer, hier schon fürs "Ohren"-Experiment im Einsatz gewesen) clippt
// stattdessen per echtem Pfad (`ctx.clip()`), ganz ohne GPU-Shader-Risiko.

// Kompakte "Auf einen Blick"-Kachel für die InfoView: Cover + Titel/Artist +
// Zeitanzeige (verstrichen/gesamt), keine weitere Steuerung. Gab es früher
// noch eine separate, voll ausgeklappte MusicView (Antippen öffnete sie) -
// die wurde ersatzlos entfernt, nur die Zeitanzeige daraus lebt hier weiter.
// Angelehnt an ~/.config/dotfiles/old/old/widgets/MediaPlayerWidget.qml,
// aber an Services.Mpris + Theme angebunden statt an den alten "Media"-Service.
Item {
    id: root

    property int coverSize: 72

    implicitWidth: 210
    implicitHeight: coverSize

    RowLayout {
        anchors.fill: parent
        spacing: 10

        Item {
            id: cover
            Layout.preferredWidth: root.coverSize
            Layout.preferredHeight: root.coverSize
            Layout.alignment: Qt.AlignVCenter

            readonly property int radius: 14

            // Placeholder-Kachel, solange kein Cover geladen ist - normales
            // Rectangle reicht, da hier kein Foto zu maskieren ist.
            Rectangle {
                anchors.fill: parent
                radius: cover.radius
                color: Theme.colors.surface
                visible: coverImage.status !== Image.Ready
            }

            LucideIcon {
                anchors.centerIn: parent
                name: "disc-3"
                size: 22
                color: Theme.colors.textMuted
                visible: coverImage.status !== Image.Ready
            }

            // Selbst unsichtbar - dient nur als Pixelquelle für den Canvas
            // darunter (siehe Kommentar oben zu Canvas vs. clip:true).
            Image {
                id: coverImage
                anchors.fill: parent
                source: Services.Mpris.artUrl
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                smooth: true
                visible: false
                onStatusChanged: if (status === Image.Ready) coverCanvas.requestPaint()
            }

            Canvas {
                id: coverCanvas
                anchors.fill: parent
                visible: coverImage.status === Image.Ready
                renderStrategy: Canvas.Cooperative

                // Ein unsichtbarer Canvas malt zwar korrekt in seinen
                // Backing-Store (onPaint läuft beim Statuswechsel oben
                // fehlerfrei durch), aber Qt Quick synct diesen Inhalt NICHT
                // automatisch zur GPU-Textur, solange visible:false ist -
                // live per Diagnose-Log bestätigt: onPaint feuerte JEDES Mal
                // erfolgreich, während canvasVisible noch false war, oft
                // über eine Sekunde bevor visible auf true wechselte
                // (die InfoView war einfach noch nicht geöffnet), und danach
                // kam nie wieder ein Paint - Cover blieb leer. Deshalb hier
                // explizit erneut malen, sobald der Canvas tatsächlich
                // sichtbar wird. `onWidthChanged`/`onHeightChanged` bleiben
                // als generelle Absicherung (Größe ändert sich bei diesem
                // Widget zwar praktisch nie, da Layout.preferredWidth/Height
                // fest sind - schadet aber nicht, für den Fall).
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onVisibleChanged: if (visible) requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const r = cover.radius
                    ctx.beginPath()
                    ctx.moveTo(r, 0)
                    ctx.lineTo(width - r, 0)
                    ctx.arcTo(width, 0, width, r, r)
                    ctx.lineTo(width, height - r)
                    ctx.arcTo(width, height, width - r, height, r)
                    ctx.lineTo(r, height)
                    ctx.arcTo(0, height, 0, height - r, r)
                    ctx.lineTo(0, r)
                    ctx.arcTo(0, 0, r, 0, r)
                    ctx.closePath()
                    ctx.clip()
                    ctx.drawImage(coverImage, 0, 0, width, height)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: Services.Mpris.available ? Services.Mpris.title : Localization.media.nothingPlaying
                color: Theme.colors.text
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: Services.Mpris.artist
                color: Theme.colors.textMuted
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 2
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            // Verstrichen/Gesamt - das Einzige, was aus der entfernten
            // MusicView übernommen wurde. Kein Slider/keine Steuerung hier,
            // nur die reine Zeitanzeige, mit "/" als Trenner statt links/
            // rechts auseinandergezogen ohne sichtbaren Bezug.
            Text {
                Layout.fillWidth: true
                visible: Services.Mpris.available
                text: Services.Mpris.formatTime(Services.Mpris.smoothPosition) + Localization.media.timeSeparator + Services.Mpris.formatTime(Services.Mpris.length)
                color: Theme.colors.textMuted
                font.family: Theme.font.family
                font.pixelSize: Theme.font.size - 3
            }
        }
    }
}
