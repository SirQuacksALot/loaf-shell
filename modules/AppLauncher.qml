import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import ".."
import "../services" as Services

// Eingebettetes Modul (kein eigener ShellRoot mehr - das darf pro Config
// nur einmal existieren, in shell.qml). Sichtbarkeit wird komplett über
// LauncherState.open gesteuert, siehe LauncherState.qml.
Scope {
    id: launcherScope

    PanelWindow {
        id: launcher

        visible: LauncherState.open

        // Vollflächiges Overlay: so können wir zentrieren und den Hintergrund abdunkeln
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusiveZone: 0
        color: "transparent"

        // Layer-Shell: über allem zeichnen. Tastatur nur greifen, wenn offen -
        // sonst würde das (unsichtbare) Fenster ständig den Fokus stehlen.
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: LauncherState.open
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell:launcher"

        onVisibleChanged: if (visible) searchField.forceActiveFocus()

        // Abgedunkelter Hintergrund - Klick daneben schließt den Launcher
        Rectangle {
            anchors.fill: parent
            color: "#99000000"
            MouseArea {
                anchors.fill: parent
                onClicked: LauncherState.hide()
            }
        }

        // Die eigentliche Launcher-Karte. Kein DropShadow (Qt5Compat.
        // GraphicalEffects) - dieses Projekt vermeidet Shader-Effekte
        // bewusst (siehe LucideIcon.qml: unzuverlässig auf manchen
        // Setups), der abgedunkelte Hintergrund + Border geben genug
        // Tiefe ohne das Risiko.
        Rectangle {
            id: launcherCard
            anchors.centerIn: parent
            width: 660
            height: 480
            radius: 20
            color: Theme.colors.background
            border.width: 1
            border.color: Theme.colors.border

            // Klicks schlucken, damit sie nicht die Schließen-Ebene erreichen
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: root
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                property string searchText: ""
                property int selectedIndex: 0
                property string selectedCategory: Localization.appLauncher.categoryAll

                onSelectedIndexChanged: appGrid.positionViewAtIndex(selectedIndex, GridView.Contain)

                // --- Kategorie-Mapping (freedesktop-Kategorien -> Anzeige-Labels) ---
                // Objekt-Keys über computed property names ([Localization...])
                // statt literaler Strings - dieselben Labels tauchen unten in
                // categoryPriority nochmal auf, vorher zwei unabhängige
                // Kopien derselben Strings (Drift-Risiko), jetzt eine
                // gemeinsame Quelle.
                readonly property var categoryGroups: ({
                    [Localization.appLauncher.categoryInternet]: ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging", "IRCClient", "Feed", "FileTransfer", "P2P", "RemoteAccess", "Telephony", "VideoConference"],
                    [Localization.appLauncher.categoryDev]: ["Development", "IDE", "WebDevelopment", "Building", "Debugger", "GUIDesigner", "Profiling", "RevisionControl", "Translation"],
                    [Localization.appLauncher.categoryMedia]: ["AudioVideo", "Audio", "Video", "Graphics", "Photography", "ImageProcessing", "Midi", "Mixer", "Sequencer", "Tuner", "TV", "AudioVideoEditing", "Player", "Recorder", "Music", "2DGraphics", "3DGraphics", "VectorGraphics", "RasterGraphics", "Scanning"],
                    [Localization.appLauncher.categoryOffice]: ["Office", "Calendar", "ContactManagement", "Spreadsheet", "WordProcessor", "Presentation", "Database", "Dictionary", "Chart", "Finance", "FlowChart", "PDA", "ProjectManagement", "Publishing"],
                    [Localization.appLauncher.categorySystem]: ["System", "Settings", "Monitor", "Security", "PackageManager", "Emulator", "Filesystem", "HardwareSettings"],
                    [Localization.appLauncher.categoryTools]: ["Utility", "Accessibility", "Archiving", "Calculator", "Clock", "Compression", "FileManager", "TerminalEmulator", "TextEditor", "ConsoleOnly", "Core", "Maps"],
                    [Localization.appLauncher.categoryGames]: ["Game", "ActionGame", "AdventureGame", "ArcadeGame", "BoardGame", "BlocksGame", "CardGame", "KidsGame", "LogicGame", "RolePlaying", "Shooter", "Simulation", "SportsGame", "StrategyGame"]
                })

                readonly property var _reverseCategoryMap: {
                    var map = {};
                    var groups = root.categoryGroups;
                    var keys = Object.keys(groups);
                    for (var k = 0; k < keys.length; k++) {
                        var displayCat = keys[k];
                        var fdCats = groups[displayCat];
                        for (var i = 0; i < fdCats.length; i++) {
                            if (!map[fdCats[i]])
                                map[fdCats[i]] = displayCat;
                        }
                    }
                    return map;
                }

                readonly property var categoryPriority: [
                    Localization.appLauncher.categoryGames, Localization.appLauncher.categoryDev,
                    Localization.appLauncher.categoryInternet, Localization.appLauncher.categoryMedia,
                    Localization.appLauncher.categoryOffice, Localization.appLauncher.categorySystem,
                    Localization.appLauncher.categoryTools
                ]

                function appCategory(app) {
                    var cats = app.categories;
                    if (!cats || cats.length === 0) return Localization.appLauncher.categoryOther;
                    var matched = {};
                    for (var i = 0; i < cats.length; i++) {
                        var mapped = _reverseCategoryMap[cats[i]];
                        if (mapped) matched[mapped] = true;
                    }
                    for (var p = 0; p < categoryPriority.length; p++) {
                        if (matched[categoryPriority[p]])
                            return categoryPriority[p];
                    }
                    return Localization.appLauncher.categoryOther;
                }

                readonly property var availableCategories: {
                    var seen = {};
                    for (var i = 0; i < allApps.length; i++)
                        seen[appCategory(allApps[i])] = true;
                    var sorted = Object.keys(seen).sort();
                    return [Localization.appLauncher.categoryAll].concat(sorted);
                }

                property var allApps: {
                    var apps = DesktopEntries.applications.values.filter(function(e) { return !e.noDisplay; });
                    var counts = Services.AppUsage.counts;
                    apps.sort(function(a, b) {
                        var ca = counts[a.name] || 0;
                        var cb = counts[b.name] || 0;
                        if (cb !== ca) return cb - ca;
                        return a.name.localeCompare(b.name);
                    });
                    return apps;
                }

                property var filteredApps: {
                    var apps = allApps;
                    if (selectedCategory !== Localization.appLauncher.categoryAll)
                        apps = apps.filter(function(e) { return appCategory(e) === selectedCategory; });
                    if (searchText.length > 0) {
                        var q = searchText.toLowerCase();
                        apps = apps.filter(function(e) { return e.name.toLowerCase().includes(q); });
                    }
                    return apps;
                }

                onFilteredAppsChanged: selectedIndex = 0

                function launchSelected() {
                    var app = filteredApps[selectedIndex];
                    if (app) {
                        Services.AppUsage.record(app.name);
                        app.execute();
                        LauncherState.hide();
                    }
                }

                // ---------------- UI ----------------

                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    horizontalAlignment: TextInput.AlignLeft
                    leftPadding: 16
                    rightPadding: 16
                    text: root.searchText

                    color: Theme.colors.text
                    font.letterSpacing: Theme.font.letterSpacing
                    font.pixelSize: Theme.font.size
                    font.family: Theme.font.family
                    font.weight: Theme.font.weight

                    background: Rectangle {
                        radius: 18
                        color: "transparent"
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: parent.leftPadding
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchField.text.length === 0
                        text: Localization.appLauncher.searchPlaceholder
                        color: Theme.colors.textMuted
                        font.letterSpacing: Theme.font.letterSpacing
                        font.pixelSize: Theme.font.size
                        font.family: Theme.font.family
                        font.weight: Theme.font.weight
                    }

                    onTextChanged: root.searchText = text

                    Keys.onPressed: event => {
                        var columns = appGrid.columns;
                        if (event.key === Qt.Key_Escape) {
                            LauncherState.hide();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Down) {
                            if (root.selectedIndex + columns < root.filteredApps.length)
                                root.selectedIndex += columns;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            if (root.selectedIndex - columns >= 0)
                                root.selectedIndex -= columns;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Left) {
                            if (root.selectedIndex > 0)
                                root.selectedIndex--;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Right) {
                            if (root.selectedIndex < root.filteredApps.length - 1)
                                root.selectedIndex++;
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.launchSelected();
                            event.accepted = true;
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.colors.borderSurface
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    contentWidth: categoryRow.width
                    clip: true
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: categoryRow
                        spacing: 6

                        Repeater {
                            model: root.availableCategories

                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool selected: root.selectedCategory === modelData
                                width: catLabel.implicitWidth + 16
                                height: 26
                                radius: 13
                                color: selected ? Theme.colors.accent : Theme.colors.surface

                                Behavior on color { ColorAnimation { duration: 120 } }

                                Text {
                                    id: catLabel
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    color: parent.selected ? Theme.colors.background : Theme.colors.text
                                    font.letterSpacing: Theme.font.letterSpacing
                                    font.pixelSize: Theme.font.size
                                    font.family: Theme.font.family
                                    font.weight: Theme.font.weight
                                    font.bold: parent.selected
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectedCategory = parent.modelData
                                }
                            }
                        }
                    }
                }

                GridView {
                    id: appGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    cellWidth: width / 8
                    cellHeight: height / 4
                    readonly property int columns: Math.max(1, Math.floor(width / cellWidth))

                    model: root.filteredApps
                    currentIndex: root.selectedIndex
                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: 25
                    highlight: Rectangle {
                        radius: 12
                        color: Theme.colors.surface
                    }

                    delegate: Item {
                        id: tile
                        width: appGrid.cellWidth
                        height: appGrid.cellHeight

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            IconImage {
                                Layout.alignment: Qt.AlignHCenter
                                implicitSize: 44
                                // Mit Reserve nach oben rastern statt exakt
                                // bei implicitSize - siehe AppsView.qml
                                // (dock/views/) für die ausführliche
                                // Begründung, gilt hier genauso.
                                backer.sourceSize: Qt.size(132, 132)
                                mipmap: true
                                source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.name
                                color: Theme.colors.text
                                font.letterSpacing: Theme.font.letterSpacing
                                font.pixelSize: Theme.font.size
                                font.family: Theme.font.family
                                font.weight: Theme.font.weight
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                // War WordWrap: bricht NICHT innerhalb eines
                                // einzelnen zu langen Worts (z.B. "GIMP",
                                // "LibreOffice" ohne Leerzeichen) - genau das
                                // ließ den Text teilweise übers Feld hinauslaufen.
                                // Wrap bricht zur Not auch mitten im Wort.
                                wrapMode: Text.Wrap
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onEntered: root.selectedIndex = index
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    const pinned = Services.Favorites.isFavorite(modelData.id);
                                    const p = tile.mapToItem(launcherCard, mouse.x, mouse.y);
                                    launcherContextMenu.openAt(p.x, p.y, [{
                                        label: pinned ? Localization.appLauncher.unpinFromDock : Localization.appLauncher.pinToDock,
                                        icon: pinned ? "pin-off" : "pin",
                                        action: () => Services.Favorites.toggle(modelData.id)
                                    }]);
                                    return;
                                }
                                root.selectedIndex = index;
                                root.launchSelected();
                            }
                        }
                    }
                }
            }

            // Zuletzt deklariert = liegt über der ganzen Launcher-Karte.
            PopupMenu { id: launcherContextMenu }
        }
    }

    // Globaler Shortcut: siehe LauncherState.qml (IpcHandler) + README für
    // die passende Kompositor-Keybind-Zeile (Hyprland/Sway/niri/...).
}

