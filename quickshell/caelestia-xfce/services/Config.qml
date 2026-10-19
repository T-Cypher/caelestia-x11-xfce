pragma Singleton

import QtQuick
import Quickshell

// caelestia-xfce user configuration.
// Edit this file (live-reloads under `qs`), or copy values you like from
// upstream Caelestia's shell.json — option names intentionally mirror it
// where an X11 equivalent exists. See PORTING.md for the mapping.
Singleton {
    id: root

    // --- Bar --------------------------------------------------------------
    // Fixed to the left edge like upstream Caelestia. On X11 the bar
    // reserves space via _NET_WM_STRUT_PARTIAL (exclusiveZone), so xfwm4
    // maximized windows will not slide underneath it.
    readonly property int barWidth: 56
    readonly property bool barShowDesktopNames: false
    readonly property int barWorkspaceCountFallback: 5  // until first EWMH poll lands
    readonly property bool barShowTray: true
    readonly property bool barShowTaskList: true

    // Desktop-entry ids pinned into the task list even when not running
    // (`ls /usr/share/applications`, strip ".desktop").
    readonly property list<string> pinnedApps: [
        "xfce4-terminal",
        "thunar",
        "firefox",
        "org.xfce.mousepad"
    ]

    // --- Default applications (X11-native replacements) --------------------
    // Upstream defaults: foot (Wayland-only!) / firefox / codium / thunar.
    // foot cannot run on X11, so the terminal default is xfce4-terminal.
    readonly property string terminal: "xfce4-terminal"
    readonly property string browser: "firefox"
    readonly property string editor: "mousepad"
    readonly property string fileManager: "thunar"
    readonly property string settingsApp: "xfce4-settings-manager"

    // --- Appearance ---------------------------------------------------------
    // xfwm4's built-in compositor gives us real alpha + shadows but
    // no background blur, so keep surfaces near-opaque: upstream runs at
    // ~0.82 alpha + Hyprland blur; here 0.96 reads as solid and legible.
    readonly property real surfaceAlpha: 0.96
    readonly property real layerAlpha: 0.98
    readonly property int rounding: 16          // drawers / cards
    readonly property int roundingSmall: 10
    readonly property int drawerMargin: 10      // gap between bar and drawers
    readonly property int animDuration: 180     // ms; X11 has no spring physics guarantee, keep short

    readonly property string fontFamily: "Rubik"
    readonly property string monoFontFamily: "JetBrainsMono Nerd Font"
    readonly property string iconFontFamily: "Material Symbols Rounded"

    // --- Behaviour ------------------------------------------------------------
    readonly property int ewmhPollMs: 2500      // safety net; xprop -spy drives instant refreshes
    readonly property int sysPollMs: 3000
    readonly property int notifTimeoutMs: 5000
    readonly property int maxNotifs: 5
    readonly property real volumeStep: 0.05
    readonly property real maxVolume: 1.5       // pactl over-amplification cap (upstream: services.maxVolume)

    readonly property string clockFormat: "hh:mm"
    readonly property string dateFormat: "ddd d MMM"

    // Path to the bundled python helpers. install.sh copies them next to
    // this config; the session launcher may override via the env var.
    readonly property string scriptsDir: {
        const override = Quickshell.env("CAELESTIA_XFCE_SCRIPTS");
        if (override && override.length > 0)
            return override;
        return Quickshell.env("HOME") + "/.config/quickshell/caelestia-xfce/scripts";
    }
}
