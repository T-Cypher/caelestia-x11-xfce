pragma Singleton

import QtQuick
import Quickshell

// Global shell UI state. Upstream keeps per-monitor ScreenState because
// Hyprland layer-shell drawers are created per output; on X11/Xfwm there
// is one virtual-desktop space across all Xinerama screens, so drawers
// are created once (primary screen) and a single open-drawer name
// ("", "launcher", "dashboard", "session") is enough.
Singleton {
    id: root

    property string openDrawer: ""

    // OSD: bump `osdRevision` (or showOsd()) to re-show/auto-hide.
    property string osdIcon: "volume_up"
    property string osdLabel: ""
    property real osdValue: 0        // 0..1 for the slider (may exceed 1 for volume >100%)
    property bool osdVisible: false

    function toggleDrawer(name) {
        openDrawer = (openDrawer === name) ? "" : name;
    }

    function closeDrawers() {
        openDrawer = "";
    }

    function showOsd(icon, label, value) {
        osdIcon = icon;
        osdLabel = label;
        osdValue = value;
        osdVisible = true;
        osdTimer.restart();
    }

    Timer {
        id: osdTimer
        interval: 1400
        onTriggered: root.osdVisible = false
    }
}
