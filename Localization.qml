pragma Singleton
import Quickshell
import QtQuick

// Zentrale Stelle für alle Text-Strings, die irgendwo in der UI angezeigt
// werden (Labels, Tooltips, Platzhalter, Status-/Fehlermeldungen, ...) -
// analog zu Theme.qml (Farben/Metrics) und Config.qml (Timing), nur für
// Text statt Optik/Bewegung. Property-Namen sind nach View/Datei gruppiert
// (ein QtObject pro Datei, die Text zeigt), damit man beim Ändern einer
// View sofort weiß, wo deren Strings hier liegen.
//
// KEIN echtes i18n-System (kein Sprachumschalten zur Laufzeit, keine
// .ts/.qm-Dateien) - reiner Zweck ist, jeden UI-Text an EINER Stelle zu
// sammeln statt über ~20 Dateien verstreut, damit man z.B. eine Formulierung
// konsistent ändern kann, ohne erst grep bemühen zu müssen. Reine
// Icon-Namen, Farben, Font-Familien, D-Bus/Prozess-Namen, Dateipfade und
// Debug-/console.warn-Texte bleiben bewusst DIREKT in ihrer Datei - die
// sind keine UI-Prosa.
//
// services/*.qml sind davon AUSGENOMMEN, auch wenn sie vereinzelt eigene
// UI-Prosa bauen (z.B. Battery.qml/formatDuration()) - Services sind reine
// Logik-Singletons ohne UI-Bezug und importieren bislang nichts aus dem
// Root-Verzeichnis (kein Theme, kein Config). Das hier reinzuziehen würde
// diese Schichtentrennung aufweichen, für ein paar wenige Strings nicht
// wert.
Singleton {
    id: root

    // Wiederverwendet über mehrere Views hinweg (Akku-/Lautstärke-/
    // Helligkeit-Prozentanzeigen, Slider-Wert-Bubble, ...) statt an jeder
    // Stelle einzeln "%" zu hartcodieren.
    readonly property QtObject common: QtObject {
        readonly property string percent: "%"
    }

    readonly property QtObject appLauncher: QtObject {
        readonly property string searchPlaceholder: "Anwendung suchen…"
        readonly property string pinToDock: "Ans Dock anheften"
        readonly property string unpinFromDock: "Vom Dock lösen"

        // Freedesktop-Kategorien -> Anzeige-Label (siehe AppLauncher.qml/
        // categoryGroups). "categoryAll"/"categoryOther" zusätzlich als
        // Pseudo-Kategorien ("Alle"-Pill, Sammelbecken für Unbekanntes).
        readonly property string categoryAll: "Alle"
        readonly property string categoryInternet: "Internet"
        readonly property string categoryDev: "Entwicklung"
        readonly property string categoryMedia: "Medien"
        readonly property string categoryOffice: "Office"
        readonly property string categorySystem: "System"
        readonly property string categoryTools: "Tools"
        readonly property string categoryGames: "Spiele"
        readonly property string categoryOther: "Sonstige"
    }

    readonly property QtObject dock: QtObject {
        readonly property string pin: "Anheften"
        readonly property string unpin: "Lösen"
        readonly property string close: "Schließen"
    }

    readonly property QtObject actionButton: QtObject {
        // Badge-Zähler-Deckel (z.B. Notification-Glocke) - "9+" statt
        // dreistelliger Zahlen in der winzigen Kachel.
        readonly property string badgeOverflow: "9+"
    }

    readonly property QtObject viewHeader: QtObject {
        readonly property string noBattery: "Kein Akku erkannt"
        readonly property string batteryFull: " · Vollständig geladen"
        readonly property string batteryCharging: " · Lädt"
        readonly property string batteryUntilFull: " bis voll"
        readonly property string batteryRemaining: " · noch "
        readonly property string wifiPrefix: "WLAN: "
        readonly property string ethernetPrefix: "Ethernet: "
        readonly property string notConnected: "Nicht verbunden"
        readonly property string close: "Schließen"
    }

    readonly property QtObject bluetooth: QtObject {
        readonly property string pairing: "Koppeln…"
        readonly property string connecting: "Verbinden…"
        readonly property string connected: "Verbunden"
        readonly property string paired: "Gekoppelt"
        readonly property string disconnect: "Trennen"
        readonly property string forget: "Vergessen"
        readonly property string turnOff: "Bluetooth ausschalten"
        readonly property string turnOn: "Bluetooth einschalten"
        readonly property string sectionLabel: "Bluetooth"
        readonly property string discovering: "Suche läuft…"
        readonly property string discoverTooltip: "20s nach Geräten suchen"
        readonly property string discoveringEmpty: "Suche nach Geräten…"
        readonly property string noDevicesFound: "Keine Geräte gefunden"
        readonly property string connectedLabel: "Verbundene Geräte"
        readonly property string knownLabel: "Bekannte Geräte"
        readonly property string foundLabel: "Andere Geräte"
    }

    readonly property QtObject clipboard: QtObject {
        readonly property string clearHistory: "Verlauf leeren"
        readonly property string notInstalled: "cliphist ist nicht installiert - kein Verlauf verfügbar."
        readonly property string empty: "Verlauf ist leer."
        readonly property string deleteEntry: "Löschen"
    }

    readonly property QtObject controlCenter: QtObject {
        readonly property string doNotDisturb: "Nicht stören"
        readonly property string idleInhibit: "Bildschirm wach halten"
        readonly property string clipboard: "Zwischenablage"
        readonly property string wallpaper: "Wallpaper"
        readonly property string powerMenu: "Power-Menü"
        readonly property string wifiLabel: "WLAN"
        readonly property string wifiTooltip: "WLAN-Einstellungen öffnen"
        readonly property string bluetoothLabel: "Bluetooth"
        readonly property string bluetoothTooltip: "Bluetooth-Einstellungen öffnen"
        readonly property string volume: "Lautstärke"
        readonly property string brightness: "Helligkeit"
        readonly property string audioSource: "Audioquelle"
        readonly property string audioSourceTooltip: "Audio-Ein-/Ausgabegerät wählen"
        readonly property string vpn: "VPN"
        readonly property string vpnTooltip: "VPN-Einstellungen öffnen"
    }

    readonly property QtObject github: QtObject {
        readonly property string notImplemented: "Noch nicht implementiert – siehe TODO-Kommentar in GithubView.qml."
        // GithubHeatmap.qml - Suffix hinter der Beitragszahl, z.B.
        // "· 234 Beiträge im letzten Jahr".
        readonly property string contributionsSeparator: " · "
        readonly property string contributionsSuffix: " Beiträge im letzten Jahr"
    }

    readonly property QtObject info: QtObject {
        readonly property string dismiss: "Verwerfen"
        readonly property string clearAll: "Alle löschen"
        readonly property string clearAllTooltip: "Alle Benachrichtigungen löschen"
    }

    readonly property QtObject powerMenu: QtObject {
        readonly property string lock: "Sperren"
        readonly property string logout: "Abmelden"
        readonly property string restart: "Neustart"
        readonly property string shutdown: "Herunterfahren"
        readonly property string confirm: "Sicher?"
    }

    readonly property QtObject wallpaper: QtObject {
        readonly property string wallhaven: "Wallhaven"
        readonly property string animeGallery: "Anime Gallery"
        readonly property string back: "Zurück"
        readonly property string searchPlaceholder: "Suchbegriff…"
        readonly property string searchTooltip: "Suchen"
        readonly property string searching: "Suche…"
        readonly property string noResults: "Keine Ergebnisse"
    }

    readonly property QtObject wifi: QtObject {
        readonly property string disconnect: "Trennen"
        readonly property string forget: "Vergessen"
        readonly property string passwordPlaceholder: "Passwort"
        readonly property string connect: "Verbinden"
        readonly property string turnOff: "WLAN ausschalten"
        readonly property string turnOn: "WLAN einschalten"
        readonly property string sectionLabel: "WLAN"
        readonly property string searchingNetworks: "Suche nach Netzwerken…"
        readonly property string knownNetworksLabel: "Bekannte Netzwerke"
        readonly property string otherNetworksLabel: "Andere Netzwerke"
        readonly property string qrTooltip: "WLAN als QR-Code teilen"
        readonly property string qrHint: "Mit dem Handy scannen, um beizutreten"
        readonly property string qrFailed: "QR-Code konnte nicht erstellt werden"
        readonly property string ipLabel: "IP-Adresse"
        readonly property string latencyLabel: "Latenz"
        readonly property string packetLossLabel: "Paketverlust"
        readonly property string receivingLabel: "Empfangen"
        readonly property string sendingLabel: "Gesendet"
        readonly property string downloadedLabel: "Heruntergeladen"
        readonly property string uploadedLabel: "Hochgeladen"
    }

    readonly property QtObject vpn: QtObject {
        // Reiter oben - eduVPN ist strukturell schon da (siehe
        // services/Vpn.qml/eduvpnConnections), aber ohne echten Client
        // dahinter noch deaktiviert (VpnView.qml: `available: false` am
        // Tab-Button).
        readonly property string tabOpenvpn: "OpenVPN"
        readonly property string tabEduvpn: "eduVPN"
        readonly property string tabEduvpnTooltip: "eduVPN wird noch nicht unterstützt"

        readonly property string connected: "Verbunden"
        readonly property string disconnected: "Getrennt"
        readonly property string connecting: "Verbindet…"
        readonly property string disconnecting: "Trennt…"
        readonly property string connect: "Verbinden"
        readonly property string disconnect: "Trennen"
        readonly property string forget: "Entfernen"
        readonly property string forgetTooltip: "Verbindung entfernen"

        readonly property string fullTunnelLabel: "Voller Tunnel"
        readonly property string splitTunnelLabel: "Split-Tunnel"
        readonly property string tunnelTooltip: "Voller Tunnel: kompletter Datenverkehr über die VPN-Verbindung. Split-Tunnel: nur die vom Server vorgegebenen Routen."
        readonly property string autoStartLabel: "Automatisch verbinden"
        readonly property string autoStartTooltip: "Beim Anmelden automatisch mit dieser Verbindung verbinden"

        readonly property string noConnections: "Keine OpenVPN-Verbindungen"
        readonly property string dropHint: "OpenVPN-Datei (.ovpn) hier ablegen"
        readonly property string dropHintActive: "Loslassen zum Hinzufügen"
        readonly property string importFailedPrefix: "Import fehlgeschlagen: "
        readonly property string actionFailedPrefix: "Fehler: "

        readonly property string ipLabel: "IP-Adresse"
        readonly property string latencyLabel: "Latenz"
        readonly property string packetLossLabel: "Paketverlust"
        readonly property string receivingLabel: "Empfangen"
        readonly property string sendingLabel: "Gesendet"
        readonly property string downloadedLabel: "Heruntergeladen"
        readonly property string uploadedLabel: "Hochgeladen"
    }

    readonly property QtObject audioSource: QtObject {
        readonly property string outputsLabel: "Ausgabe"
        readonly property string inputsLabel: "Eingabe"
        readonly property string noOutputs: "Keine Ausgabegeräte gefunden"
        readonly property string noInputs: "Keine Eingabegeräte gefunden"
    }

    readonly property QtObject battery: QtObject {
        // BatteryIndicator.qml - Overlay bei kritischem Ladestand.
        readonly property string critical: "!"
        // services/Battery.qml (formatDuration(), z.B. "3h 12min") bleibt
        // BEWUSST unlokalisiert - siehe Kopfkommentar dieser Datei:
        // Services sind reine Logik-Singletons ohne UI-Bezug, sollen also
        // nichts aus dem Root-Verzeichnis importieren.
    }

    readonly property QtObject calendar: QtObject {
        readonly property var dayShortLabels: ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
        readonly property var dayLetterLabels: ["S", "M", "D", "M", "D", "F", "S"]
    }

    readonly property QtObject media: QtObject {
        readonly property string nothingPlaying: "Nichts läuft"
        readonly property string timeSeparator: " / "
    }

    readonly property QtObject osd: QtObject {
        // Anzeige-Label je Hyprland-Submap (siehe services/Osd.qml/
        // Configs/hyprland/.config/hypr/modules/bindings.lua) - Key ist der
        // interne Submap-Name (1:1 wie in bindings.lua), Value das, was in
        // der OSD steht. Unbekannte Submaps fallen in modules/OsdOverlay.qml
        // auf den rohen internen Namen zurück, statt hier gepflegt werden
        // zu müssen.
        readonly property var submapNames: ({
            "shell": "Shell",
            "scrolloverview": "Fenster-Übersicht"
        })
    }

    readonly property QtObject polkit: QtObject {
        readonly property string heading: "Authentifizierung erforderlich"
        readonly property string cancel: "Abbrechen"
        readonly property string passwordPlaceholder: "Passwort"
        readonly property string ok: "OK"
    }
}
