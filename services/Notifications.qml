pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Eigener Notification-Daemon. Sobald diese Datei irgendwo im Baum
// instanziiert wird (siehe shell.qml), übernimmt QuickShell die Rolle
// des Desktop-Notification-Servers (org.freedesktop.Notifications).
//
// WICHTIG: Es darf immer nur EIN Notification-Daemon gleichzeitig laufen.
// Falls dein System bereits einen hat (z.B. dunst, mako, swaync), diesen
// vorher deaktivieren/deinstallieren, sonst schlägt die DBus-Registrierung fehl.
Singleton {
    id: root

    // Zuletzt eingetroffener Eintrag - für die Dynamic-Island-Transformation
    // (NotifyView.qml, der kurze Toast). Derselbe Snapshot-Eintrag wie in
    // `_history` (s.u.), NICHT die rohe Notification - genau das war der
    // Bug: schließt die Quelle das zugrunde liegende Objekt im Hintergrund
    // (siehe `_history`-Kommentar, passiert bei vesktop ständig), während
    // der Toast noch die vollen `notifyDuration` sichtbar ist, hätte
    // NotifyView.qml auf einem bereits toten Objekt gelesen. Der Snapshot
    // bleibt unabhängig davon gültig. `var` statt `Notification`, weil ein
    // Eintrag ein normales JS-Objekt ist, kein Notification-Typ.
    property var latest: null

    // Eigene, dauerhafte Historie statt eines reinen Spiegels von
    // `server.trackedNotifications` (das war früher `list`). Grund: Apps
    // wie vesktop/Discord schließen ihre EIGENEN vorherigen Notifications
    // aktiv (CloseNotification), sobald schnell hintereinander mehrere
    // Nachrichten reinkommen - vermutlich um die System-Notification-
    // Zentrale nicht zuzuspammen. Live-Test mit 9 Nachrichten in Folge:
    // 9 echte, verschiedene DBus-Notifications kamen an, aber vesktop hat
    // 7 davon selbst sofort wieder geschlossen, sobald die jeweils
    // nächste da war - nur die allererste + die letzte blieben am
    // OS-Level offen. Ein reiner Live-Spiegel zeigt dadurch fälschlich
    // nur 2 von 9. Diese Historie hier bleibt davon unberührt: jede
    // ankommende Notification landet hier dauerhaft, unabhängig davon,
    // ob die Quelle sie im Hintergrund selbst schließt - verschwindet
    // nur noch, wenn DU sie wegklickst (dismiss()/clearAll()).
    //
    // Jeder Eintrag: { id, appName, summary, body, image, notification }.
    // Anzeige-Felder (appName/summary/body/image) sind als Snapshot
    // separat gespeichert, nicht nur als Referenz aufs Notification-
    // Objekt - ein bereits von der Quelle geschlossenes Objekt gibt seine
    // Properties nicht mehr zuverlässig her. `notification` ist die LIVE-
    // Referenz für dismiss() weiter unten, wird auf null gesetzt, sobald
    // das zugrunde liegende Objekt selbst geschlossen wird (siehe
    // closedTracker unten) - danach räumt dismiss() nur noch bei uns auf,
    // ohne (mehr nötigen) Aufruf auf ein bereits totes Objekt.
    property var _history: []

    readonly property var list: root._history
    readonly property int count: root._history.length

    // Wie `list`, aber nach appName gruppiert - für InfoView.qml, um
    // Notifications derselben App gestapelt statt als lose Einzelkarten
    // darzustellen. Jede Gruppe: { appName, notifications } (letzteres
    // selbst wieder neueste zuerst, da `list` das bereits ist). Die
    // Gruppen-Reihenfolge ergibt sich automatisch richtig: eine Gruppe
    // taucht an der Stelle ihrer ERSTEN (= neuesten) Notification in
    // `list` auf, alles Ältere derselben App wird nur noch angehängt.
    readonly property var groupedList: {
        const groups = [];
        const byApp = {};
        for (const n of root.list) {
            if (!byApp[n.appName]) {
                byApp[n.appName] = { appName: n.appName, notifications: [] };
                groups.push(byApp[n.appName]);
            }
            byApp[n.appName].notifications.push(n);
        }
        return groups;
    }

    // Do-Not-Disturb: Notifications werden weiter getrackt (landen in der
    // Liste), aber die Insel poppt nicht mehr automatisch auf. Umgeschaltet
    // aus dem Control Center (modules/island/views/ControlCenterView.qml).
    property bool doNotDisturb: false

    function toggleDnd() {
        root.doNotDisturb = !root.doNotDisturb;
        saveDnd();
    }

    // Nimmt sowohl einen Eintrag aus `_history`/`latest` (der Normalfall -
    // Klick auf "x" in InfoView.qml oder NotifyView.qml) als auch eine
    // rohe Notification direkt entgegen, falls die mal irgendwo ohne
    // Umweg über einen Eintrag vorliegt. Beide Formen haben ein `id` -
    // darüber wird in JEDEM Fall auch der Historie-Eintrag entfernt,
    // falls einer existiert.
    function dismiss(item) {
        const raw = (typeof item.dismiss === "function") ? item : item.notification;
        if (raw) {
            try { raw.dismiss(); } catch (e) { /* Quelle hat's evtl. schon selbst geschlossen */ }
        }
        root._history = root._history.filter(e => e.id !== item.id);
    }

    // "default" ist die freedesktop-Notification-Konvention für "das
    // passiert, wenn man auf die Notification SELBST klickt" (statt auf
    // einen eigens benannten Action-Button) - z.B. Vencords "Update
    // verfügbar"-Hinweis nutzt genau das für seinen Neustart-Hinweis.
    // Andere, eigenständig benannte Actions (z.B. "Antworten") bleiben
    // davon unberührt und bekommen ihren eigenen Button (siehe
    // NotificationCard in InfoView.qml) - hier zentral statt in NotifyView.qml
    // UND InfoView.qml separat dupliziert, beide nutzen das gleichermaßen
    // (Toast-Fläche antippen bzw. Notification-Karte antippen).
    // Gibt zurück, ob tatsächlich eine Default-Action gefunden+ausgelöst wurde
    // (Aufrufer entscheiden selbst, was das für sie bedeutet - z.B. NotifyView
    // schließt den Toast so oder so, unabhängig vom Rückgabewert).
    function invokeDefaultAction(entry) {
        if (!entry || !entry.notification) return false;
        for (const action of entry.notification.actions) {
            if (action.identifier === "default") {
                try {
                    action.invoke();
                } catch (e) {
                    console.warn("Notifications: Default-Action konnte nicht ausgeführt werden:", e);
                }
                return true;
            }
        }
        return false;
    }

    function clearAll() {
        for (const e of root._history) {
            if (e.notification) {
                try { e.notification.dismiss(); } catch (err) { /* schon weg */ }
            }
        }
        root._history = [];
    }

    function saveDnd() {
        try {
            dndFile.setText(JSON.stringify({ doNotDisturb: root.doNotDisturb }));
        } catch (e) {
            console.warn("Notifications: DND-Status konnte nicht gespeichert werden:", e);
        }
    }

    FileView {
        id: dndFile
        path: Quickshell.dataPath("notifications-dnd.json")
        preload: true
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(dndFile.text());
                root.doNotDisturb = !!parsed.doNotDisturb;
            } catch (e) {
                root.doNotDisturb = false;
            }
        }
    }

    // Tracer, der EIN einzelnes Notification-Objekt beobachtet und den
    // zugehörigen Historie-Eintrag von der (dann toten) Live-Referenz
    // trennt, sobald die Quelle es selbst schließt - siehe `_history`
    // oben. Dynamisch pro Notification erzeugt (Anzahl variiert), zerstört
    // sich nach dem `closed`-Signal selbst.
    Component {
        id: closedTracker
        Connections {
            id: tracerRoot
            property var entry
            property var n
            target: tracerRoot.n
            function onClosed() {
                tracerRoot.entry.notification = null;
                tracerRoot.destroy();
            }
        }
    }

    NotificationServer {
        id: server

        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: false
        persistenceSupported: true
        keepOnReload: true

        onNotification: notification => {
            notification.tracked = true;

            const entry = {
                id: notification.id,
                appName: notification.appName,
                summary: notification.summary,
                body: notification.body,
                image: notification.image,
                notification: notification
            };
            root.latest = entry;
            // Sortiert nach id einfügen statt blind vorne anzuhängen:
            // `keepOnReload` feuert onNotification nach einem QML-Reload
            // erneut für alle vorher schon getrackten Notifications (zum
            // Wiederaufbau von `_history`, die selbst ein reines JS-Array
            // ist und einen Reload nicht übersteht) - deren Reihenfolge
            // ist dabei nicht garantiert die ursprüngliche Ankunftsreihenfolge.
            const next = root._history.concat([entry]);
            next.sort((a, b) => b.id - a.id);
            root._history = next;

            closedTracker.createObject(root, { entry: entry, n: notification });
        }
    }
}
