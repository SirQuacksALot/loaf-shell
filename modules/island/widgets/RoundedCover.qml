import QtQuick
import "../.."
import "../../.."

// Rundes Vorschaubild mit Fallback-Icon, falls keine Bildquelle vorhanden
// ist oder das Laden fehlschlägt - z.B. Cover Art einer Notification
// (Discord gibt z.B. den Avatar des Absenders mit, siehe NotificationCard
// in InfoView.qml) oder generell überall dort, wo mal ein rundes Vorschau-
// bild mit sinnvollem Leerzustand gebraucht wird.
//
// Selbe Canvas-Clip-Technik wie das MPRIS-Cover in MediaWidget.qml (dort
// ausführlicher kommentiert): "Rectangle { clip: true }" clippt nur auf
// die rechteckige Bounding-Box, NICHT auf `radius` - ein Bild darin
// behält eckige Ecken. Der Klassiker dafür wäre ein Shader-Effekt
// (OpacityMask/MultiEffect), den dieses Projekt bewusst vermeidet (siehe
// LucideIcon.qml - unzuverlässig auf manchen Setups). Canvas clippt
// stattdessen per echtem Pfad (ctx.clip()), ganz ohne GPU-Shader-Risiko.
Item {
    id: root

    property string source: ""
    property int size: 36
    property int radius: 10
    property string fallbackIcon: "bell"
    property color fallbackIconColor: Theme.colors.textMuted

    implicitWidth: size
    implicitHeight: size

    // Platzhalter-Kachel + Icon, solange kein Bild geladen ist (keine
    // Quelle, noch am Laden, oder Laden fehlgeschlagen).
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.colors.surface
        visible: image.status !== Image.Ready
    }

    LucideIcon {
        anchors.centerIn: parent
        name: root.fallbackIcon
        size: Math.round(root.size * 0.5)
        color: root.fallbackIconColor
        visible: image.status !== Image.Ready
    }

    // Selbst unsichtbar - dient nur als Pixelquelle für den Canvas
    // darunter.
    Image {
        id: image
        anchors.fill: parent
        source: root.source.length > 0 ? root.source : ""
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        smooth: true
        visible: false
        onStatusChanged: if (status === Image.Ready) canvas.requestPaint()
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        visible: image.status === Image.Ready
        renderStrategy: Canvas.Cooperative

        // Siehe MediaWidget.qml: ein unsichtbarer Canvas malt zwar korrekt
        // in seinen Backing-Store, Qt Quick synct das aber nicht
        // automatisch zur GPU-Textur, solange visible:false ist - deshalb
        // hier explizit erneut malen, sobald der Canvas tatsächlich
        // sichtbar wird.
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const r = root.radius
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
            ctx.drawImage(image, 0, 0, width, height)
        }
    }
}
