pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Material-3 palette. Defaults are the stock "caelestia" scheme shipped
// with the dotfiles (hypr/scheme/default.lua in caelestia-dots/caelestia).
// If caelestia-cli has written ~/.local/state/caelestia/scheme.json we
// load that instead, exactly like upstream services/Colours.qml — so
// `caelestia scheme set ...` keeps working on X11 for the shell itself.
Singleton {
    id: root

    property bool light: false

    // Surfaces (pre-multiplied with the flat X11 alpha from Config)
    property color surface: "#131317"
    property color surfaceDim: "#131317"
    property color surfaceBright: "#39393d"
    property color surfaceContainerLowest: "#0e0e12"
    property color surfaceContainerLow: "#1c1b1f"
    property color surfaceContainer: "#201f23"
    property color surfaceContainerHigh: "#2a292e"
    property color surfaceContainerHighest: "#353438"
    property color m3onSurface: "#e5e1e7"
    property color surfaceVariant: "#47464f"
    property color m3onSurfaceVariant: "#c8c5d1"
    property color outline: "#918f9a"
    property color outlineVariant: "#47464f"

    property color primary: "#c2c1ff"
    property color m3onPrimary: "#2a2a60"
    property color primaryContainer: "#7171ac"
    property color m3onPrimaryContainer: "#ffffff"
    property color secondary: "#c6c4e0"
    property color m3onSecondary: "#2e2e44"
    property color secondaryContainer: "#45455c"
    property color m3onSecondaryContainer: "#b4b2ce"
    property color tertiary: "#f5b2e0"
    property color m3onTertiary: "#4e1e44"
    property color tertiaryContainer: "#bb7da9"
    property color m3onTertiaryContainer: "#000000"
    property color error: "#ffb4ab"
    property color m3onError: "#690005"
    property color errorContainer: "#93000a"
    property color m3onErrorContainer: "#ffdad6"
    property color success: "#b5ccba"
    property color m3onSuccess: "#213528"
    // NOTE: the m3 prefix on `on*` names is required, not stylistic: QML
    // forbids declaring properties named onXxx (signal-handler syntax).
    // Upstream does exactly the same (m3primary, m3onPrimary, ...).
    // Convenience alpha'd containers (xfwm4 has no blur: keep flat).
    readonly property color barBg: Qt.alpha(surface, Config.surfaceAlpha)
    readonly property color drawerBg: Qt.alpha(surface, Config.layerAlpha)
    readonly property color cardBg: surfaceContainer
    readonly property color cardBgHover: surfaceContainerHigh

    function loadSchemeJson(text) {
        let scheme;
        try {
            scheme = JSON.parse(text);
        } catch (e) {
            console.warn("caelestia-xfce: could not parse scheme.json:", e);
            return;
        }
        if (!scheme || !scheme.colours)
            return;
        root.light = scheme.mode === "light";
        for (const key in scheme.colours) {
            // scheme.json keys are unprefixed ("onPrimary"); our matching
            // property is "m3onPrimary" (see note above).
            const prop = root.hasOwnProperty(key) ? key : ("m3" + key);
            if (root.hasOwnProperty(prop))
                root[prop] = "#" + scheme.colours[key];
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"
        watchChanges: true
        printErrors: false
        onLoaded: root.loadSchemeJson(text())
        onFileChanged: reload()
    }
}
