pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick

// Every notification the shell has heard, for the banners and the
// notification center. The shell is the session's notification server
// (plasmashell, which would be, doesn't run in Ambrosia).
//
// A notification stays with its app after its banner leaves, as GNOME keeps
// it and as a Mac keeps it in Notification Center: its actions still work
// from there, and it closes only when it's clicked, cleared, or its app takes
// it back. Expiring it when the banner left would tell the app it was
// refused (bluedevil takes that as Cancel). Only transient ones, and the
// oldest past a limit, are let go when their banner leaves.
//
// Focus (Do Not Disturb) holds back the banners of all but urgent ones; they
// still reach the center. An app turned off in Settings is held back whatever
// it says, and kept nowhere. Settings' list of apps is those heard from here.
// The center's list outlives the shell (statePath, notifications.json); after
// a restart its entries have no app on the other end, and a click opens the
// app instead.
Singleton {
    id: store

    // What the center lists, newest first: { key, nid, app, entry, icon,
    // summary, body, time, urgent }. nid is the live notification's id, or
    // -1 once it's gone (it came from before a restart, or was let go).
    property var history: []
    // The notifications with a banner up, newest first, as { nid }.
    readonly property ListModel banners: ListModel {}
    // The center's history by app, the app heard from last first:
    // { app, entry, icon, records (newest first), time }.
    readonly property var groups: {
        const byApp = new Map();
        for (const record of history) {
            const name = record.app || "Notification";
            if (!byApp.has(name))
                byApp.set(name, { app: name, entry: record.entry, icon: record.icon, records: [], time: record.time });
            byApp.get(name).records.push(record);
        }
        return Array.from(byApp.values());
    }
    readonly property bool centerOpen: Popups.kind === "notificationCenter"

    property int nextKey: 1
    readonly property int keepLive: 32
    readonly property int keepRecords: 100

    readonly property NotificationServer server: NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: notification => store.heard(notification)
    }

    // The live notification with this id, or null.
    function live(nid) {
        if (nid < 0) return null;
        return server.trackedNotifications.values.find(n => n.id === nid) ?? null;
    }

    function entryOf(notification) {
        const id = notification.desktopEntry;
        return (id && DesktopEntries.byId(id)) || DesktopEntries.heuristicLookup(notification.appName) || null;
    }

    // The notification's own picture, else its app's icon, as a source URL.
    function iconOf(notification, entry) {
        const icon = notification.appIcon;
        if (notification.image) return notification.image;
        if (icon.startsWith("/")) return "file://" + icon;
        if (icon.includes("://")) return icon;
        return (icon ? Quickshell.iconPath(icon, true) : "") || Quickshell.iconPath(entry?.icon ?? "", "dialog-information");
    }

    function heard(notification) {
        const entry = entryOf(notification);
        const app = notification.appName || entry?.name || "";
        if (app !== "") {
            const known = Settings.notificationApps.some(each => each.split("\t")[0] === app);
            if (!known)
                Settings.notificationApps = Settings.notificationApps.concat([`${app}\t${entry?.icon ?? notification.appIcon ?? ""}`]);
            if (Settings.notificationsOff.includes(app)) return;
        }
        const urgent = notification.urgency === NotificationUrgency.Critical;
        // A transient one held back has nothing left to show.
        const quiet = Settings.doNotDisturb && !urgent;
        if (quiet && notification.transient) return;

        notification.tracked = true;
        const nid = notification.id;
        notification.closed.connect(reason => store.gone(nid, reason));

        if (!notification.transient) {
            const record = {
                key: nextKey++, nid: nid, app: app, entry: entry?.id ?? notification.desktopEntry ?? "",
                icon: iconOf(notification, entry), summary: notification.summary, body: notification.body,
                time: Date.now(), urgent: urgent,
            };
            history = [record].concat(history).slice(0, keepRecords);
            letGoOldest();
            saveSoon.restart();
        }
        // In the center already when it's open, unless it needs an answer.
        const waits = urgent || notification.expireTimeout === 0;
        if (!quiet && (!centerOpen || waits))
            banners.insert(0, { nid: nid });
    }

    // Its app closed it, or it was clicked or cleared: out of the center
    // too. Let go (expired) by us, it stays listed.
    function gone(nid, reason) {
        dropBanner(nid);
        if (reason === NotificationCloseReason.Expired) {
            history = history.map(r => r.nid === nid ? Object.assign({}, r, { nid: -1 }) : r);
        } else {
            history = history.filter(r => r.nid !== nid);
        }
        saveSoon.restart();
    }

    function dropBanner(nid) {
        for (let i = 0; i < banners.count; i++) {
            if (banners.get(i).nid === nid) {
                banners.remove(i);
                return;
            }
        }
    }

    // A banner's time is up: it goes, the notification stays in the center
    // (a transient one goes altogether).
    function bannerDone(nid) {
        dropBanner(nid);
        const notification = live(nid);
        if (notification && (notification.transient || !history.some(r => r.nid === nid)))
            notification.expire();
    }

    // Past keepLive, the oldest are let go: still listed, no longer live.
    function letGoOldest() {
        const liveOnes = history.filter(r => r.nid >= 0);
        for (const record of liveOnes.slice(keepLive)) {
            if (bannerUp(record.nid)) continue;
            live(record.nid)?.expire();
        }
    }

    function bannerUp(nid) {
        for (let i = 0; i < banners.count; i++) {
            if (banners.get(i).nid === nid) return true;
        }
        return false;
    }

    // A click on a notification: its default action if its app still
    // listens, else its app brought forward (or started), as a Mac opens it.
    function open(record) {
        const notification = live(record.nid);
        const action = notification?.actions.find(a => a.identifier === "default") ?? null;
        if (action) {
            action.invoke();
            if (notification.resident) dismissOne(record);
            return;
        }
        if (record.entry) Apps.activateEntry(record.entry);
        dismissOne(record);
    }

    // A click on a banner: the same, for one the center may not list.
    function openLive(nid) {
        const record = history.find(r => r.nid === nid);
        if (record) {
            dropBanner(nid);
            open(record);
            return;
        }
        const notification = live(nid);
        const action = notification?.actions.find(a => a.identifier === "default") ?? null;
        if (action) action.invoke();
        else if (notification) notification.dismiss();
    }

    function dismissOne(record) {
        const notification = live(record.nid);
        history = history.filter(r => r.key !== record.key);
        if (notification) notification.dismiss();
        saveSoon.restart();
    }
    function clearApp(app) {
        const going = history.filter(r => (r.app || "Notification") === app);
        history = history.filter(r => (r.app || "Notification") !== app);
        for (const record of going) live(record.nid)?.dismiss();
        saveSoon.restart();
    }
    function clearAll() {
        const going = history;
        history = [];
        for (const record of going) live(record.nid)?.dismiss();
        saveSoon.restart();
    }

    // Opening the center takes the banners in, but for those waiting on an answer.
    onCenterOpenChanged: {
        if (!centerOpen) return;
        for (let i = banners.count - 1; i >= 0; i--) {
            const notification = live(banners.get(i).nid);
            const waits = notification && (notification.urgency === NotificationUrgency.Critical || notification.expireTimeout === 0);
            if (!waits) banners.remove(i);
        }
    }

    // Kept across restarts; what's read back has no app on the other end.
    FileView {
        id: file
        path: Quickshell.statePath("notifications.json")
        printErrors: false
        onLoaded: {
            let saved = [];
            try {
                saved = JSON.parse(text()) ?? [];
            } catch (e) {
                saved = [];
            }
            if (!Array.isArray(saved)) return;
            const restored = saved.map(r => Object.assign({}, r, { nid: -1, key: store.nextKey++ }));
            store.history = store.history.concat(restored).slice(0, store.keepRecords);
        }
    }
    Timer {
        id: saveSoon
        interval: 1000
        onTriggered: {
            // What a live one says now: apps update theirs in place.
            const records = store.history.map(r => {
                const notification = store.live(r.nid);
                return notification ? Object.assign({}, r, { summary: notification.summary, body: notification.body }) : r;
            });
            file.setText(JSON.stringify(records));
        }
    }
}
