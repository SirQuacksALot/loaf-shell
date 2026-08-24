import QtQuick
import ".."

// Wiederverwendbares Rechtsklick-Kontextmenü - Liste von {label, icon,
// action}-Einträgen, an einem beliebigen Punkt geöffnet. Genutzt von
// Dock.qml (laufende/angepinnte Apps: Anheften/Lösen, Schließen) und
// AppLauncher.qml (Anheften/Lösen statt des alten Sterns).
// Heißt PopupMenu statt ContextMenu - Letzteres kollidierte mit einem
// intern von QtQuick.Controls registrierten, nicht erstellbaren Typ
// gleichen Namens ("Type cannot be created in QML").
//
// Einbindung: als letztes Kind im jeweiligen Fenster/Root-Item platzieren
// (anchors.fill: parent), damit der Backdrop das GANZE Fenster abdeckt und
// das Menü über allem anderen liegt. Öffnen per `openAt(x, y, entries)`.
Item {
    id: root

    anchors.fill: parent

    property var entries: []
    property bool menuVisible: false
    property real menuX: 0
    property real menuY: 0

    readonly property int _rowHeight: 30
    readonly property int _menuWidth: 180

    function openAt(px, py, newEntries) {
        if (newEntries !== undefined) root.entries = newEntries
        // Nicht über den rechten/unteren Rand hinaus öffnen.
        root.menuX = Math.min(px, root.width - root._menuWidth - 4)
        root.menuY = Math.min(py, root.height - (root.entries.length * root._rowHeight + 8) - 4)
        root.menuVisible = true
    }
    function close() {
        root.menuVisible = false
    }

    // Backdrop - jeder Klick außerhalb des Menüs schließt es. Liegt VOR
    // dem Menü im Baum, wird also von dessen TapHandlern überdeckt/
    // "gewinnt" nicht gegen sie (Stapelreihenfolge = Deklarationsreihenfolge).
    MouseArea {
        anchors.fill: parent
        visible: root.menuVisible
        enabled: root.menuVisible
        onClicked: root.close()
        acceptedButtons: Qt.LeftButton | Qt.RightButton
    }

    Rectangle {
        id: menu
        visible: root.menuVisible
        x: root.menuX
        y: root.menuY
        width: root._menuWidth
        height: list.implicitHeight + 8
        radius: 10
        color: Theme.colors.surface
        border.width: 1
        border.color: Theme.colors.borderSurface

        Column {
            id: list
            anchors.fill: parent
            anchors.margins: 4

            Repeater {
                model: root.entries

                delegate: Rectangle {
                    id: row
                    required property var modelData

                    width: list.width
                    height: root._rowHeight
                    radius: 6
                    color: rowHover.hovered ? Theme.colors.border : "transparent"

                    Behavior on color { ColorAnimation { duration: Theme.animationDurations.short } }

                    LucideIcon {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        name: row.modelData.icon
                        size: 14
                        color: Theme.colors.textMuted
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 30
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.label
                        color: Theme.colors.text
                        font.family: Theme.font.family
                        font.pixelSize: Theme.font.size - 1
                        elide: Text.ElideRight
                    }

                    HoverHandler { id: rowHover }
                    TapHandler {
                        onTapped: {
                            row.modelData.action()
                            root.close()
                        }
                    }
                }
            }
        }
    }
}
