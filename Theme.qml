pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property QtObject colors: QtObject {
        readonly property color background: "#161616"
        readonly property color surface: "#2b2b2b"
        readonly property color accent: "#ca9ee6"
        readonly property color accentSoft: "#f4b8e4"
        readonly property color muted: "#6c7086"

        readonly property color text: "#f5f5f5"
        readonly property color textMuted: "#c6c6c6"

        readonly property color border: "#262626"
        readonly property color borderSurface: "#3b3b3b"

        readonly property color success: "#a6d189"
        readonly property color warning: "#e5c890"
        readonly property color error: "#e78284"
        readonly property color info: "#9ac2cd"
    }

    readonly property QtObject font: QtObject {
        readonly property string family: "SF Mono"
        readonly property int size: 12
        readonly property int weight: 600
        readonly property int letterSpacing: -1
    }

    readonly property QtObject metrics: QtObject {
        readonly property int radius: 18
        readonly property int spacing: 6
        readonly property int barHeight: 34
    }

    readonly property QtObject animationDurations: QtObject {
        readonly property int normal: 250
        readonly property int short: 200
        readonly property int long: 350
    }

}
