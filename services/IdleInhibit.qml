pragma Singleton
import QtQuick
import Quickshell

// Hält NUR den gewünschten Zustand ("soll der Bildschirm gerade NICHT
// sperren/dimmen, ja/nein"). Das eigentliche Wayland-Idle-Inhibit-
// Protokoll-Objekt braucht zwingend ein an ein echtes Surface gebundenes
// Fenster (siehe IdleInhibitor.window in modules/IdleInhibitAnchor.qml) -
// das gehört hier bewusst NICHT rein, gleiches Trennungsmuster wie z.B.
// Osd.qml (reiner Zustand) vs. OsdOverlay.qml (Fenster/Darstellung).
//
// Bewusst NICHT wie Notifications.doNotDisturb über eine FileView
// persistiert - das ist hier ein Sicherheits-Feature, kein Komfort-
// Setting: würde der Zustand einen Quickshell-Neustart überleben, bliebe
// der Rechner nach einem Crash/Neustart der Shell unbemerkt für immer
// wach, obwohl niemand das aktiv nochmal angefordert hat. Setzt sich
// dadurch bei jedem Quickshell-Start bewusst auf "aus" zurück.
Singleton {
    id: root

    property bool inhibited: false

    function toggle() {
        root.inhibited = !root.inhibited;
    }
}
