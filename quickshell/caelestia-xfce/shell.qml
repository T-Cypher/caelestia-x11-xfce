//@ pragma DefaultEnv QT_QPA_PLATFORM=xcb
//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded

// caelestia-xfce — a Caelestia-inspired Quickshell desktop shell for
// Xfce (xfwm4) on X11. See PORTING.md for how every upstream
// Hyprland/Wayland mechanism was mapped (or deliberately dropped).
//
// Run via:  caelestia-xfce-session          (installed wrapper)
//      or:  QT_QPA_PLATFORM=xcb qs -c caelestia-xfce
// IPC:      qs -c caelestia-xfce ipc call drawers toggle launcher
//           qs -c caelestia-xfce ipc call sys volumeUp
//           qs -c caelestia-xfce ipc call wm nextDesktop

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.bar
import qs.modules.drawers
import qs.modules.overlays
import qs.services

ShellRoot {
    id: root

    settings.watchFiles: true

    // Touch singletons once so their pollers/servers start even before
    // a referencing window paints.
    Component.onCompleted: {
        console.log("caelestia-xfce starting (EWMH desktops: " + Wm.desktops.length + ", notifs: " + Notifs.list.length + ")");
    }

    component BarPerScreen: Bar {
        required property var modelData
        screen: modelData
    }

    // One bar per screen. xfwm4 desktops span all Xinerama screens, so
    // every bar shows identical state (no per-monitor workspaces on X11).
    Variants {
        model: Quickshell.screens

        BarPerScreen {}
    }

    // Drawers + overlays live on the primary screen only.
    Launcher {}
    Dashboard {}
    Session {}
    NotifPopups {}
    Osd {}

    // Keyboard entry point. There is no Quickshell.Hyprland
    // GlobalShortcut on X11: bind these IPC calls in Xfce
    // (scripts/apply-keybinds.sh does it via xfconf-query).
    IpcHandler {
        target: "drawers"

        function toggle(name: string): void {
            ShellState.toggleDrawer(name);
        }
        function open(name: string): void {
            ShellState.openDrawer = name;
        }
        function close(): void {
            ShellState.closeDrawers();
        }
        function launcher(): void {
            ShellState.toggleDrawer("launcher");
        }
        function dashboard(): void {
            ShellState.toggleDrawer("dashboard");
        }
        function session(): void {
            ShellState.toggleDrawer("session");
        }
    }
}
