import QtQuick
import ".."

// Wiederverwendbarer Hover-Tooltip für Buttons (ActionButton/MenuButton/
// Toggle). Reparentet sich selbst auf das Root-Item des umgebenden
// Fensters (Window.window.contentItem) statt im Eltern-Baum zu bleiben -
// so entkommt er JEDEM clip:true auf dem Weg dorthin (z.B.
// MorphContainer.surface, das Dock/Island-Fläche clippt), ganz ohne dass
// jede aufrufende View eine eigene "popupLayer"-Durchreichung bräuchte
// (das Muster, das Dock/AppLauncher für ihre Kontextmenüs nutzen - hier
// bewusst nicht nötig, weil Window.window unabhängig von der
// Verschachtelungstiefe immer verfügbar ist).
//
// Einbindung (siehe ActionButton.qml): als Kind in einen Button, target
// auf den Button selbst, hovered an dessen HoverHandler gebunden.
Item {
    id: root

    required property Item target
    property string text: ""
    property bool hovered: false
    property int delay: 450

    readonly property Item _layer: target.Window.window ? target.Window.window.contentItem : null

    Timer {
        id: showTimer
        interval: root.delay
        onTriggered: if (root.hovered && root.text.length > 0) bubble.visible = true
    }
    onHoveredChanged: {
        if (root.hovered) showTimer.restart()
        else { showTimer.stop(); bubble.visible = false }
    }
    onTextChanged: bubble.visible = false

    Rectangle {
        id: bubble
        parent: root._layer || root
        visible: false
        z: 10000
        radius: 6
        color: Theme.colors.surface
        border.width: 1
        border.color: Theme.colors.borderSurface
        width: label.implicitWidth + 16
        height: label.implicitHeight + 10

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Theme.colors.text
            font.family: Theme.font.family
            font.pixelSize: Theme.font.size - 3
        }

        // Erst bei tatsächlichem Sichtbarwerden positionieren
        // (imperativ, nicht als reaktive Bindung) - mapToItem() innerhalb
        // eines Bindings verfolgt nicht zuverlässig die volle Vorfahren-
        // Transformationskette (siehe Dock-Tooltip-Historie), nur explizit
        // gelesene Properties wie target.width. Beim Öffnen einmalig
        // berechnen reicht hier, da Buttons ihre Position nicht ändern,
        // während gehovert wird.
        onVisibleChanged: if (visible) root._reposition()
    }

    function _reposition() {
        if (!root._layer) return
        const pos = root.target.mapToItem(root._layer, root.target.width / 2, root.target.height)
        bubble.x = Math.max(4, Math.min(pos.x - bubble.width / 2, root._layer.width - bubble.width - 4))
        bubble.y = Math.min(pos.y + 6, root._layer.height - bubble.height - 4)
    }
}
