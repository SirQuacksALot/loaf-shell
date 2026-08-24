import QtQuick
import Quickshell
import Quickshell.Io

// Rendert ein Lucide-SVG aus <shell-root>/icons/<name>.svg.
//
// Lucide-SVGs nutzen stroke="currentColor", was der Qt-SVG-Renderer ohne
// CSS-Kontext nicht auflösen kann. Statt eines Shader-Effekts (MultiEffect
// braucht Qt >= 6.4 + funktionierende GPU-Pipeline und lieferte bei manchen
// Setups schwarze Icons) ersetzen wir "currentColor" einfach direkt im
// SVG-Text durch die Zielfarbe, bevor es geladen wird. Das funktioniert
// überall zuverlässig.
Item {
    id: root

    property string name: "circle"
    property int size: 18
    property color color: "white"

    implicitWidth: size
    implicitHeight: size

    property bool fileLoaded: false

    FileView {
        id: svgFile
        // Quickshell.shellDir zeigt immer auf den Ordner von shell.qml,
        // unabhängig davon, aus welchem Unterordner LucideIcon.qml
        // aufgerufen wird. icons/ liegt dort direkt daneben.
        path: Quickshell.shellDir + "/icons/" + root.name + ".svg"
        preload: true
        printErrors: false
        onLoaded: root.fileLoaded = true
    }

    readonly property string coloredSvg: {
        if (!root.fileLoaded) return ""
        return svgFile.text().replace(/currentColor/g, root.color.toString())
    }

    Image {
        anchors.fill: parent
        source: root.coloredSvg.length > 0
            ? "data:image/svg+xml;utf8," + encodeURIComponent(root.coloredSvg)
            : ""
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
