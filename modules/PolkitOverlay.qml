import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import ".."
import "island" as Island

// Eigener Polkit-Passwort-Dialog als EINZELNES, globales Overlay-Fenster -
// bewusst NICHT Teil der pro-Bildschirm Dynamic Island (modules/island/).
// Genau das war der Grund, warum sich die Abfrage früher auf JEDEM Monitor
// gleichzeitig geöffnet hat: IslandRoot.qml existiert einmal PRO BILDSCHIRM
// (siehe shell.qml/Variants), der (frühere) globale Polkit-Singleton hat
// dadurch jede einzelne Instanz gleichzeitig getriggert.
//
// Muster stattdessen von AppLauncher.qml übernommen (ebenfalls nur EINMAL
// instanziiert, siehe shell.qml, KEIN Variants/Quickshell.screens): dieses
// PanelWindow bindet bewusst KEIN `screen:` (anders als IslandRoot/Dock/
// ScreenCorners) - Quickshell platziert ein PanelWindow ohne explizites
// `screen:` von sich aus auf dem gerade compositor-fokussierten Monitor,
// ganz ohne Hyprland-IPC-Abfrage. Ein früherer Versuch, das Öffnen stattdessen
// per Hyprland.monitorFor()/isFocusedScreen()-Gate direkt im
// IslandRoot.qml-Connections-Handler einzuschränken, brach die Anfrage aus
// ungeklärten Gründen komplett (siehe Git-Historie) - diese Lösung braucht
// so einen Gate gar nicht erst, weil es von Anfang an nur noch EIN Fenster
// gibt.
//
// `PolkitAgent {}` MUSS irgendwo im Baum instanziiert werden, damit
// Quickshell sich überhaupt bei Polkit als Agent registriert - hier direkt,
// kein eigener services/-Singleton mehr nötig (es gibt jetzt nur noch diese
// eine Stelle, die ihn braucht). `agent.flow` ist bereits eine native,
// reaktive Property (Signal `flowChanged`) - kein manuelles
// Zwischenspeichern in einer eigenen `currentFlow`-Property mehr nötig, wie
// es der frühere services/PolkitAgent.qml-Wrapper gemacht hat.
Scope {
    id: root

    PolkitAgent {
        id: agent
    }

    readonly property var flow: agent.flow

    function submit() {
        if (!root.flow) return;
        // WICHTIG: submit(), nicht respond() - respond() existiert auf
        // AuthFlow gar nicht (siehe quickshell-service-polkit.qmltypes).
        // Der frühere Aufruf lief dadurch immer in den catch-Block unten
        // und tat schlicht nichts - vermutlich die eigentliche Ursache
        // dafür, dass "OK"/Enter nie sichtbar etwas ausgelöst hat.
        try {
            root.flow.submit(passwordField.text);
        } catch (e) {
            console.warn("PolkitOverlay: submit() fehlgeschlagen:", e);
        }
        passwordField.text = "";
    }

    function cancelFlow() {
        if (!root.flow) return;
        try {
            root.flow.cancelAuthenticationRequest();
        } catch (e) {
            console.warn("PolkitOverlay: cancelAuthenticationRequest() fehlgeschlagen:", e);
        }
    }

    PanelWindow {
        id: window

        visible: root.flow !== null
        color: "transparent"
        exclusiveZone: 0

        anchors { top: true; bottom: true; left: true; right: true }

        WlrLayershell.layer: WlrLayer.Overlay
        // Exclusive nur während tatsächlich eine Anfrage aussteht - ein
        // Passwort-Prompt MUSS Tastatureingaben bekommen, egal wo die Maus
        // gerade ist (gleiches Muster wie AppLauncher.qml/LauncherState.open).
        WlrLayershell.keyboardFocus: root.flow !== null ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell:polkit"

        onVisibleChanged: if (visible) passwordField.forceActiveFocus()

        // Neuer Flow (z.B. zweite Anfrage direkt nach Abschluss der ersten)
        // - Feld soll wieder leer sein und erneut Fokus bekommen, statt das
        // alte (evtl. falsche) Passwort stehen zu lassen.
        Connections {
            target: root
            function onFlowChanged() {
                passwordField.text = "";
                if (root.flow) passwordField.forceActiveFocus();
            }
        }

        // Bewusst KEIN abgedunkelter Hintergrund mit Klick-zum-Schließen wie
        // bei AppLauncher: eine versehentlich weggeklickte Polkit-Anfrage
        // lässt die eigentliche Aktion irgendwo im System hängen (die auf
        // genau diese Antwort wartet) - das wäre schlimmer als ein Launcher,
        // der sich einfach erneut öffnen lässt. Abbrechen geht bewusst nur
        // explizit über den X-Button oder Escape.
        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 400
            height: content.implicitHeight + content.anchors.margins * 2
            radius: Theme.metrics.radius
            color: Theme.colors.background
            border.width: 1
            border.color: Theme.colors.border

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    LucideIcon {
                        Layout.alignment: Qt.AlignTop
                        name: "shield-lock"
                        size: 28
                        color: Theme.colors.accent
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: Localization.polkit.heading
                            color: Theme.colors.text
                            font.family: Theme.font.family
                            font.pixelSize: Theme.font.size
                            font.bold: true
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: root.flow ? root.flow.message : ""
                            color: Theme.colors.textMuted
                            font.family: Theme.font.family
                            font.pixelSize: Theme.font.size - 2
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                    }

                    Island.ActionButton {
                        icon: "x"
                        iconSize: 14
                        diameter: 22
                        Layout.alignment: Qt.AlignTop
                        tooltip: Localization.polkit.cancel
                        onTapped: root.cancelFlow()
                    }
                }

                // Zusätzliche PAM-Rückmeldung (z.B. "Falsches Passwort,
                // erneut versuchen") - separat von der Haupt-Message oben,
                // kommt erst nach einem fehlgeschlagenen Versuch rein.
                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.flow ? root.flow.supplementaryMessage : ""
                    color: (root.flow && root.flow.supplementaryIsError) ? Theme.colors.error : Theme.colors.textMuted
                    font.family: Theme.font.family
                    font.pixelSize: Theme.font.size - 2
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: !root.flow || root.flow.isResponseRequired

                    TextField {
                        id: passwordField
                        Layout.fillWidth: true
                        // responseVisible == false bedeutet "als Passwort
                        // maskieren" (Standardfall) - true nur bei einer
                        // Rückfrage, die tatsächlich im Klartext beantwortet
                        // werden soll (z.B. Ja/Nein-artige PAM-Prompts).
                        echoMode: (root.flow && root.flow.responseVisible) ? TextInput.Normal : TextInput.Password
                        placeholderText: (root.flow && root.flow.inputPrompt) ? root.flow.inputPrompt : Localization.polkit.passwordPlaceholder
                        color: Theme.colors.text
                        font.family: Theme.font.family
                        font.pixelSize: Theme.font.size - 1
                        background: Rectangle {
                            radius: 8
                            color: Theme.colors.surface
                            border.width: 1
                            border.color: Theme.colors.borderSurface
                        }
                        onAccepted: root.submit()
                        Keys.onEscapePressed: root.cancelFlow()
                    }

                    Island.MenuButton {
                        showLabel: true
                        label: Localization.polkit.ok
                        contentPadding: 12
                        Layout.preferredHeight: 34
                        onTapped: root.submit()
                    }
                }
            }
        }
    }
}
