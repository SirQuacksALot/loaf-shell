import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import ".."
import "../.."
import "../../.."
import "../../../services" as Services

// Kompakte Contribution-Heatmap fürs Control Center (angelehnt an
// Whisker: https://github.com/corecathx/whisker). Datenquelle + Persistenz
// siehe services/GithubStats.qml. Zellgröße wird aus der tatsächlich
// verfügbaren Breite berechnet (nicht hart codiert) - sonst genau der
// Überlauf-Bug, der uns in InfoView schon mal eingeholt hat.
//
// Username per Klick editierbar: Text -> TextField-Umschaltung über
// `editing`. Bestätigt wird per Enter ODER dem Haken-Button, verworfen per
// Escape ODER dem X-Button - bewusst KEIN automatisches Bestätigen bei
// Fokusverlust mehr (sonst würde ein Klick auf den X-Button selbst erst
// per Fokusverlust bestätigen, bevor der Cancel überhaupt ankommt).
ColumnLayout {
    id: root
    spacing: 6

    property bool editing: false

    readonly property int weekCount: Math.max(1, Math.ceil(Services.GithubStats.contributions.length / 7))
    readonly property real cellSpacing: 2

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        // Rundes Profilbild statt eines statischen Icons - "<user>.png"
        // ist GitHubs eigener, undokumentierter aber seit Jahren stabiler
        // Convenience-Redirect auf den Avatar, kein API-Token nötig (im
        // Unterschied zur eigentlichen Contribution-API, siehe
        // services/GithubStats.qml). Rund zugeschnitten per Canvas +
        // ctx.clip() statt Rectangle.clip:true (das clippt nur auf die
        // rechteckige Bounding-Box, nie auf eine Kreisform) und ganz ohne
        // Shader-Effekt (OpacityMask/MultiEffect) - selbe Technik wie das
        // Cover in widgets/MediaWidget.qml, dort ausführlich begründet.
        Item {
            id: avatar
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16

            readonly property string url: Services.GithubStats.username.length > 0
                ? "https://github.com/" + encodeURIComponent(Services.GithubStats.username) + ".png?size=64" : ""

            // Placeholder, solange kein Bild geladen ist bzw. der Request
            // fehlschlägt (z.B. Username-Tippfehler während der Bearbeitung).
            LucideIcon {
                anchors.fill: parent
                name: "square-code"
                size: 13
                color: Theme.colors.textMuted
                visible: avatarImage.status !== Image.Ready
            }

            // Selbst unsichtbar - dient nur als Pixelquelle für den Canvas
            // darunter.
            Image {
                id: avatarImage
                anchors.fill: parent
                source: avatar.url
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                smooth: true
                visible: false
                onStatusChanged: if (status === Image.Ready) avatarCanvas.requestPaint()
            }

            Canvas {
                id: avatarCanvas
                anchors.fill: parent
                visible: avatarImage.status === Image.Ready
                renderStrategy: Canvas.Cooperative

                // Siehe MediaWidget.qml: ein unsichtbarer Canvas malt zwar
                // korrekt in seinen Backing-Store, aber Qt Quick synct das
                // nicht zur GPU-Textur, solange visible:false ist - daher
                // beim Sichtbarwerden explizit erneut malen.
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onVisibleChanged: if (visible) requestPaint()

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.beginPath()
                    ctx.arc(width / 2, height / 2, Math.min(width, height) / 2, 0, Math.PI * 2)
                    ctx.closePath()
                    ctx.clip()
                    ctx.drawImage(avatarImage, 0, 0, width, height)
                }
            }
        }

        Text {
            visible: !root.editing
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: "@" + Services.GithubStats.username + Localization.github.contributionsSeparator + Services.GithubStats.totalCount + Localization.github.contributionsSuffix
            color: Theme.colors.textMuted
            font.family: Theme.font.family
            font.pixelSize: Theme.font.size - 3

            TapHandler {
                onTapped: {
                    usernameField.text = Services.GithubStats.username
                    root.editing = true
                    usernameField.forceActiveFocus()
                    usernameField.selectAll()
                }
            }
        }

        TextField {
            id: usernameField
            visible: root.editing
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            font.family: Theme.font.family
            font.pixelSize: Theme.font.size - 3
            color: Theme.colors.text
            selectByMouse: true
            leftPadding: 8
            rightPadding: 8
            topPadding: 0
            bottomPadding: 0

            background: Rectangle {
                radius: 6
                color: Theme.colors.surface
                border.width: 1
                border.color: Theme.colors.accent
            }

            function confirm() {
                Services.GithubStats.setUsername(usernameField.text)
                root.editing = false
            }
            function cancel() {
                usernameField.text = Services.GithubStats.username
                root.editing = false
            }

            onAccepted: confirm()
            Keys.onEscapePressed: cancel()
        }

        ActionButton {
            visible: root.editing
            icon: "check"
            iconSize: 13
            diameter: 22
            showBackground: false
            iconColor: Theme.colors.success
            onTapped: usernameField.confirm()
        }
        ActionButton {
            visible: root.editing
            icon: "x"
            iconSize: 13
            diameter: 22
            showBackground: false
            onTapped: usernameField.cancel()
        }
    }

    Item {
        id: grid
        Layout.fillWidth: true
        Layout.preferredHeight: grid.cellSize * 7 + root.cellSpacing * 6

        readonly property real cellSize: Math.max(2,
            (grid.width - (root.weekCount - 1) * root.cellSpacing) / root.weekCount)

        Row {
            anchors.fill: parent
            spacing: root.cellSpacing

            Repeater {
                model: root.weekCount

                delegate: Column {
                    required property int index
                    spacing: root.cellSpacing

                    Repeater {
                        model: 7

                        delegate: Rectangle {
                            required property int index

                            // parent = die umgebende Column (Wochen-Spalte,
                            // vom ÄUSSEREN Repeater instanziiert) - Repeater
                            // selbst hängt nicht im visuellen Baum, seine
                            // Kinder landen direkt im Parent-Item.
                            readonly property var day: Services.GithubStats.contributions[parent.index * 7 + index]

                            width: grid.cellSize
                            height: grid.cellSize
                            radius: Math.min(2, grid.cellSize / 3)
                            color: {
                                if (!day) return "transparent"
                                const lvl = day.level || 0
                                if (lvl <= 0) return Theme.colors.surface
                                const steps = [0.4, 0.6, 0.8, 1.0]
                                const a = steps[Math.min(lvl - 1, 3)]
                                return Qt.rgba(Theme.colors.accent.r, Theme.colors.accent.g, Theme.colors.accent.b, a)
                            }
                        }
                    }
                }
            }
        }
    }
}
