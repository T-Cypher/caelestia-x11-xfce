pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.services

// Notification daemon (org.freedesktop.Notifications), replacing
// xfce4-notifyd the same way upstream replaces mako/dunst on Wayland.
// IMPORTANT: only one process may own that D-Bus name — install.sh
// masks xfce4-notifyd's autostart entry (reversibly).
Singleton {
    id: root

    // Live Notification objects, newest first.
    property var list: []
    // notification.id -> epoch ms when it arrived (for auto-expire)
    property var arrivedAt: ({})

    function remove(notif) {
        root.list = root.list.filter(n => n !== notif);
    }

    function dismissAll() {
        for (const n of root.list.slice())
            n.dismiss();
        root.list = [];
    }

    NotificationServer {
        id: server

        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: false
        bodyHyperlinksSupported: false
        imageSupported: true
        persistenceSupported: false
        keepOnReload: false

        onNotification: notification => {
            notification.tracked = true;
            root.arrivedAt[notification.id] = Date.now();
            let next = [notification].concat(root.list);
            if (next.length > Config.maxNotifs) {
                for (const old of next.slice(Config.maxNotifs))
                    old.expire();
                next = next.slice(0, Config.maxNotifs);
            }
            root.list = next;
        }
    }

    // Expire non-critical popups after Config.notifTimeoutMs, and prune
    // anything the server has already untracked (replaced/expired by app).
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            const now = Date.now();
            let changed = false;
            const keep = [];
            for (const n of root.list) {
                const critical = (n.urgency !== undefined && n.urgency >= 2);
                const age = now - (root.arrivedAt[n.id] || now);
                if (!n.tracked) {
                    changed = true;
                } else if (!critical && age > Config.notifTimeoutMs) {
                    n.expire();
                    changed = true;
                } else {
                    keep.push(n);
                }
            }
            if (changed)
                root.list = keep;
        }
    }
}
