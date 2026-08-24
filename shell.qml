//@ pragma IconTheme Reversal-purple-dark
import Quickshell
import QtQuick
import "./modules"
import "./modules/island"
import "./modules/dock"

// Einstiegspunkt. Wird von quickshell automatisch geladen
// (~/.config/quickshell/shell.qml).
//
// Die eigentliche Logik steckt in ./services (Audio, Battery, Network,
// Notifications, Windows, Favorites, Mpris, Lyrics, Bluetooth, Brightness,
// NightLight, Osd - alles Singletons) und ./modules (die sichtbaren
// Komponenten). Die Dynamic Island lebt in ./modules/island, der Dock in
// ./modules/dock (siehe dortiges README.md für die Struktur + wie man
// neue Views ergänzt). Der
// Notification-Daemon (services/Notifications.qml) wird bereits durch
// IslandRoot.qml beim Start referenziert und läuft daher von Anfang an,
// auch bevor die Insel je gehovert wurde.
ShellRoot {
    Variants {
        model: Quickshell.screens

        delegate: Component {
            Scope {
                id: perScreen
                required property var modelData

                IslandRoot {
                    screen: perScreen.modelData
                }

                Dock {
                    screen: perScreen.modelData
                }

                ScreenCorners {
                    screen: perScreen.modelData
                }
            }
        }
    }

    // Nur einmal (nicht pro Bildschirm) - öffnet sich auf dem
    // aktuell fokussierten Monitor.
    AppLauncher {}

    // Nur einmal (nicht pro Bildschirm, siehe dortiger Kommentar) - öffnet
    // sich ebenfalls auf dem aktuell fokussierten Monitor, exakt wie
    // AppLauncher oben.
    PolkitOverlay {}

    // Dito - Lautstärke-/Helligkeit-/Submap-OSD, siehe services/Osd.qml.
    OsdOverlay {}
}
