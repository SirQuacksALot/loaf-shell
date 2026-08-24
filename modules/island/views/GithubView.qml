import QtQuick
import QtQuick.Layouts
import ".."
import "../.."
import "../../.."

// STUB - GitHub-Contribution-Heatmap. Erreichbar über den GitHub-Shortcut
// in ControlCenterView.qml, aber noch ohne Funktion.
//
// Empfohlener Aufbau:
//  - GitHub GraphQL API (https://docs.github.com/graphql, query
//    `contributionsCollection.contributionCalendar`) mit einem Personal
//    Access Token (nur "read:user"-Scope nötig). Token NICHT hier im
//    Quellcode ablegen - z.B. per FileView aus ~/.config/quickshell/secrets
//    lesen (mit restriktiven Dateirechten) oder aus einem Passwort-Manager.
//  - Als services/GithubStats.qml Singleton kapseln: XMLHttpRequest wie in
//    services/Lyrics.qml, Ergebnis (Datum -> Anzahl Commits) einmal täglich
//    abrufen und lokal cachen (Quickshell.dataPath), nicht bei jedem
//    Insel-Öffnen neu laden.
//  - Rendering: Grid aus kleinen Rectangles (7 Zeilen x ~52 Wochen), Farbe
//    nach Commit-Anzahl gestuft (z.B. Theme.colors.surface -> accent).
MorphItem {
    id: view

    name: "github"
    preferredWidth: 460
    preferredHeight: 180

    required property var islandRoot

    onActiveChanged: if (view.active) view.forceActiveFocus()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        ViewHeader { islandRoot: view.islandRoot }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: Localization.github.notImplemented
            color: Theme.colors.textMuted
            wrapMode: Text.WordWrap
            font.family: Theme.font.family
            font.pixelSize: Theme.font.size - 2
            verticalAlignment: Text.AlignVCenter
        }
    }
}
