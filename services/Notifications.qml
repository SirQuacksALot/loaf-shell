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
    // darzustellen. Jede Zeile: { appName, notificationIds } (letzteres
    // selbst wieder neueste zuerst) - bewusst nur IDs, keine vollen
    // Einträge, siehe Kommentar bei `notificationIds` unten.
    //
    // WICHTIG: Das ist bewusst ein echtes, INKREMENTELL gepflegtes
    // ListModel statt einer bei jeder `_history`-Änderung komplett neu
    // berechneten `var`-Property (das war es früher - ein Array aus
    // frischen JS-Objekten, bei JEDER einzelnen Notification neu gebaut,
    // direkt als ListView.model in InfoView.qml verwendet). Genau dasselbe
    // Anti-Pattern wie beim `actions`-Repeater dort (siehe dortiger
    // Kommentar zum `.filter()`-Fix vom 28.08.) - nur ungleich wirkungsvoller,
    // weil es die GESAMTE Notification-Liste bei JEDEM Event betraf: ein
    // frisches Array wird von QML als komplett neues Model interpretiert,
    // die ListView wirft dabei ALLE Delegates weg und inkubiert sie neu.
    // Bei einer großen, nie manuell geleerten Historie plus `keepOnReload`
    // (feuert `onNotification` beim Start einmal PRO alter Notification neu,
    // siehe unten) lief das als Burst von komplett neuen Modellen in
    // Folge - genau das hat wiederholt zu SIGSEGV-Abstürzen tief in Qts
    // QML-Engine geführt (QQmlIncubatorPrivate::incubate ->
    // writeKnownVarProperty -> VariantAssociationPrototype::fromQVariantMap,
    // 5 bestätigte Crash-Reports zwischen 28.08. und 01.09.). Mit einem
    // ListModel + insert/move/setProperty/remove ändert sich bei einem
    // einzelnen Event immer nur EINE Zeile - alle anderen Gruppen-Delegates
    // bleiben unangetastet bestehen, kein Massen-Reinkubieren mehr.
    readonly property ListModel groupedModel: ListModel {}

    // Liefert den Index der Gruppe zu appName, oder -1.
    function _groupIndex(appName) {
        for (let i = 0; i < root.groupedModel.count; i++) {
            if (root.groupedModel.get(i).appName === appName) return i;
        }
        return -1;
    }

    // Nachschlagen des vollen Eintrags per id - einzige Quelle bleibt
    // `_history`, das Grouped-Model selbst hält nur IDs (s.u.).
    function entryById(id) {
        return root._history.find(e => e.id === id) || null;
    }

    // Geschützter Zugriff auf die Actions-Sequenz eines Eintrags - direkt
    // in einem QML-Binding gelesen (`entry.notification.actions`) wirft
    // das eine TypeError, sobald `entry.notification` zwar nicht null,
    // das zugrunde liegende native Objekt aber schon tot ist (siehe
    // invokeDefaultAction() oben für den identischen Fall). Ein Binding
    // kann kein try/catch haben - deshalb hier als Funktion, InfoView.qml
    // nutzt NUR noch diese statt `entry.notification.actions` direkt
    // anzufassen.
    function safeActions(entry) {
        if (!entry || !entry.notification) return [];
        try {
            return entry.notification.actions;
        } catch (e) {
            return [];
        }
    }

    // Neuen Eintrag einsortieren. Gruppenreihenfolge = Position der jeweils
    // NEUESTEN Notification (gleiche Regel wie früher) - eine Gruppe landet
    // deshalb bei einem neuen Eintrag immer vorne (Index 0), egal ob sie
    // gerade erst entsteht (insert) oder schon existiert (move).
    //
    // WICHTIG: `notificationIds` ist ein KOMMAGETRENNTER STRING, kein
    // Array. Erster Versuch war ein echtes Array aus IDs (Zahlen) - live
    // getestet und live widerlegt: JEDES Array, das man einer ListModel-
    // Rolle zuweist, wandelt QML automatisch in ein eigenes verschachteltes
    // Sub-Model um (`get(idx).notificationIds` lieferte dabei ein Objekt
    // mit `count`/`dynamicRoles`/... statt eines JS-Arrays) - unabhängig
    // davon, ob die Array-Elemente Objekte oder simple Zahlen sind. Ein
    // String-Wert bleibt dagegen ein normaler Skalar, komplett immun
    // gegen diese Automatik. `.split(",").map(Number)` baut daraus ganz
    // regulär (außerhalb der ListModel-Rolle, in einer normalen
    // property var im Delegate) wieder ein echtes Array. Die vollen
    // Notification-Daten kommen bei Bedarf per `entryById()` aus `_history`.
    function _addToGroups(entry) {
        const idx = root._groupIndex(entry.appName);
        if (idx === -1) {
            root.groupedModel.insert(0, { appName: entry.appName, notificationIds: String(entry.id) });
            return;
        }
        const ids = entry.id + "," + root.groupedModel.get(idx).notificationIds;
        root.groupedModel.setProperty(idx, "notificationIds", ids);
        if (idx !== 0) root.groupedModel.move(idx, 0, 1);
    }

    // Entfernt einen Eintrag (per id) aus JEDER Gruppe, in der er vorkommt -
    // spiegelt dieselbe Semantik wie der `_history`-Filter unten (kein
    // Abbruch nach dem ersten Treffer). Rückwärts iterieren, weil
    // `remove()` nachfolgende Indizes verschiebt. Wird eine Gruppe dabei
    // leer, verschwindet die Zeile komplett - die nächstältere Notification
    // rutscht automatisch nach, weil `notificationIds[0]` in InfoView.qml
    // neu bindet, sobald sich die Zeile ändert.
    function _removeFromGroups(entryId) {
        for (let i = root.groupedModel.count - 1; i >= 0; i--) {
            const group = root.groupedModel.get(i);
            const ids = group.notificationIds.split(",").map(Number);
            const filtered = ids.filter(id => id !== entryId);
            if (filtered.length === ids.length) continue;
            if (filtered.length === 0) {
                root.groupedModel.remove(i);
            } else {
                root.groupedModel.setProperty(i, "notificationIds", filtered.join(","));
            }
        }
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
        root._removeFromGroups(item.id);
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
        // Der obige Null-Check schützt nur gegen den saubereren Fall, dass
        // unser closedTracker `entry.notification` schon selbst auf null
        // gesetzt hat (siehe dort). Er schützt NICHT gegen ein bereits vom
        // nativen Objekt her TOTES Notification-Objekt, dessen JS-Referenz
        // trotzdem noch nicht null ist - passiert bei Apps wie vesktop
        // ständig (schließen eigene ältere Notifications selbst im
        // Hintergrund, siehe `_history`-Kommentar oben). Der Zugriff auf
        // `.actions` wirft dann eine TypeError, live beobachtet (u.a. als
        // letzte Log-Zeile vor einem der SIGSEGV-Crash-Reports vom 31.08.).
        // Deshalb der GESAMTE Zugriff im try/catch, nicht nur invoke().
        try {
            for (const action of entry.notification.actions) {
                if (action.identifier === "default") {
                    action.invoke();
                    return true;
                }
            }
        } catch (e) {
            console.warn("Notifications: Default-Action konnte nicht ausgeführt werden (Notification vermutlich bereits ungültig):", e);
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
        root.groupedModel.clear();
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
            root._addToGroups(entry);

            closedTracker.createObject(root, { entry: entry, n: notification });
        }
    }
}
