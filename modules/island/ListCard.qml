import QtQuick
import QtQuick.Layouts
import "../.."

// Einheitliche Zeilen-Kachel für Listen-Einträge - 44px hoch, rund,
// surface-farben, 8px Innenabstand. Ursprünglich nur die Notification-
// Karten in InfoView.qml, jetzt überall dort, wo eine View eine
// scrollbare Liste von "Dingen" zeigt (WLAN-Netz, Bluetooth-Gerät,
// Zwischenablage-Eintrag) - eine Stelle für "wie groß/wie sieht ein
// Listen-Eintrag aus", statt N leicht abweichender eigener Zeilenhöhen
// pro View. NICHT für WallpaperView (Thumbnail-Kacheln, komplett andere
// Form/Optik) und NICHT für PowerMenuView (nutzt stattdessen MenuButton
// im Text-Modus, wie die WLAN/Bluetooth-Buttons im Control Center).
//
// Kein Layout.fillWidth/-preferredHeight - wird meist per anchors in
// einem ListView-Wrapper-Item positioniert (siehe WifiView.qml/
// BluetoothView.qml für die Begründung: Qt Quick Layouts erlauben keine
// anchors auf ihren Kindern), Breite kommt von dort. Wo stattdessen
// direkt in einem Layout genutzt (z.B. das "verbundene Netz" außerhalb
// der scrollbaren Liste), setzt der Aufrufer Layout.fillWidth selbst.
//
// Root ist ein einfaches Item statt direkt ein Rectangle - der Hover-
// Hintergrund ist ein eigenes Rectangle DAHINTER (siehe unten), damit nur
// ER ein-/ausblendet und nicht der Inhalt (Icon/Text/Buttons) mit. Ein
// `Behavior on color` zwischen "transparent" und einer deckenden Farbe
// war der erste Versuch dafür - sichtbarer Fehler: Qt interpoliert dabei
// Alpha UND RGB unabhängig voneinander, mittendrin blitzt kurz Schwarz
// durch (ähnliches Problem wie die Shader-Effekte, die dieses Projekt
// bewusst meidet, siehe LucideIcon.qml). Eine reine Opacity-Animation auf
// einer durchgehend surface-farbenen Fläche hat dieses Problem nicht.
Item {
    id: root

    // true = Höhe wächst mit dem Inhalt (z.B. ClipboardView.qml: Text mit
    // wrapMode statt einzeiligem elide) statt der festen 44px - fürs
    // "gleich groß wie eine Notification-Karte" WLAN/Bluetooth/
    // Notifications, für "beliebig langer, umbrechender Text" Clipboard.
    property bool fitContent: false

    // implicitHeight zusätzlich zu height: ein Item bindet implicitHeight
    // NICHT automatisch an height. Genau das brach WifiView.qml/
    // BluetoothView.qml: deren ListView-Wrapper-Item liest
    // `content.implicitHeight`, um seine eigene Höhe zu setzen (Qt Quick
    // Layouts erlauben keine anchors auf ihren Kindern, daher der
    // Umweg) - ohne implicitHeight kam dabei 0 raus, die komplette Liste
    // kollabierte auf 0px Zeilenhöhe. Aus demselben Grund hier bewusst
    // NICHT `implicitHeight: row.implicitHeight + 16` direkt an height
    // gebunden gelassen, sondern beide explizit gleichgesetzt.
    height: root.fitContent ? row.implicitHeight + 16 : 44
    implicitHeight: root.height

    readonly property alias hovered: hoverHandler.hovered
    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    // Von außen gesetzt (z.B. Pfeiltasten-Auswahl in einer ListView) -
    // treibt denselben Hintergrund wie Hover, siehe unten. Getrennt von
    // `hovered` (das ist rein die Maus), damit ein Aufrufer beides
    // unabhängig auswerten kann, falls mal nötig.
    property bool selected: false

    // Ausnahme vom "nur bei Hover"-Standard unten: die Notification-Karte
    // in InfoView.qml (siehe NotificationCard dort) braucht IMMER eine
    // Fläche, nicht nur bei Hover - sie steht dort als "oberste Karte
    // eines Stapels" neben den dekorativen Peek-Rändern (siehe
    // GroupCard-Delegate), die dieselbe Theme.colors.surface-Fläche
    // zeigen. Bei genau EINER Notification gibt es aber gar keinen
    // Peek-Rand (nichts zu stapeln) - ohne diese Property hing die Karte
    // dann komplett rahmenlos in der Luft (live gemeldeter Bug: "sieht aus
    // wie ein Stack, dem die oberste Karte fehlt"). WLAN/Bluetooth/
    // Clipboard bleiben unverändert beim Hover-only-Verhalten.
    property bool alwaysVisible: false

    default property alias content: row.data
    property alias spacing: row.spacing

    // Standardmäßig unsichtbar (verschmilzt mit dem View-Hintergrund),
    // bei Hover ODER externer `selected` eingeblendet - stärker "Zeile,
    // mit der du gerade interagierst/die gerade ausgewählt ist" als
    // "dauerhaft abgesetzte Kachel".
    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.colors.surface
        opacity: (root.alwaysVisible || hoverHandler.hovered || root.selected) ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: Theme.animationDurations.short } }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8
    }
}
