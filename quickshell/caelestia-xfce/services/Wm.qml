pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// ---------------------------------------------------------------------------
// Wm — the X11/EWMH replacement for upstream services/Hypr.qml.
//
// Upstream API (Hyprland IPC)          This file (xfwm4, EWMH)
// ------------------------------       -------------------------------------
// Hyprland.workspaces          ->      desktops[]  (_NET_NUMBER_OF_DESKTOPS)
// Hyprland.focusedWorkspace    ->      currentDesktop (_NET_CURRENT_DESKTOP)
// Hyprland.toplevels           ->      windows[]   (_NET_CLIENT_LIST + xprop)
// Hyprland.activeToplevel      ->      activeWindow (_NET_ACTIVE_WINDOW)
// Hyprland.dispatch("workspace N") ->  wmctrl -s N   (was no IPC socket here)
// Hyprland.dispatch("killactive")->    wmctrl -i -c <id>
// Hyprland raw events          ->      `xprop -root -spy` PropertyNotify stream
//                                       + a slow safety-net poll
//
// There is no X11 equivalent of Hyprland *special* (scratchpad)
// workspaces, per-monitor workspaces or window tags, so those upstream
// features are intentionally absent here (see PORTING.md).
// ---------------------------------------------------------------------------
Singleton {
    id: root

    property var windows: []            // [{id,title,wmClass,desktop,...}]
    property var desktops: []           // [{index,name,windowCount,occupied}]
    property int currentDesktop: 0
    property string activeWindowId: ""
    property bool ready: false

    readonly property var activeWindow: {
        for (let i = 0; i < windows.length; i++)
            if (windows[i].id === activeWindowId)
                return windows[i];
        return null;
    }
    readonly property string activeTitle: activeWindow ? (activeWindow.title || activeWindow.wmClass) : ""
    readonly property string activeClass: activeWindow ? activeWindow.wmClass : ""
    readonly property bool hasFullscreen: windows.some(w => w.fullscreen && (w.desktop === currentDesktop || w.desktop === -1))

    function windowsOnDesktop(index) {
        return windows.filter(w => w.desktop === index || w.desktop === -1);
    }

    // --- Actions (EWMH client messages via wmctrl/xdotool) -------------------
    function switchDesktop(index) {
        Quickshell.execDetached(["wmctrl", "-s", String(index)]);
        refreshSoon.restart();
    }

    function relativeDesktop(delta) {
        const count = Math.max(desktops.length, 1);
        switchDesktop(((currentDesktop + delta) % count + count) % count);
    }

    function activateWindow(id) {
        Quickshell.execDetached(["wmctrl", "-i", "-a", id]);
        refreshSoon.restart();
    }

    function closeWindow(id) {
        Quickshell.execDetached(["wmctrl", "-i", "-c", id]);
        refreshSoon.restart();
    }

    function minimizeWindow(id) {
        Quickshell.execDetached(["xdotool", "windowminimize", id]);
        refreshSoon.restart();
    }

    function moveWindowToDesktop(id, index) {
        Quickshell.execDetached(["wmctrl", "-i", "-r", id, "-t", String(index)]);
        refreshSoon.restart();
    }

    function moveActiveToDesktop(index) {
        if (activeWindowId)
            moveWindowToDesktop(activeWindowId, index);
    }

    // Task-list click behaviour borrowed from xfce4-panel: raise, or
    // minimize if already the focused window.
    function toggleWindow(id) {
        if (id === activeWindowId)
            minimizeWindow(id);
        else
            activateWindow(id);
    }

    // --- State fetching -------------------------------------------------------
    function refresh() {
        if (!poll.running)
            poll.running = true;
    }

    function applySnapshot(snap) {
        if (!snap || !snap.ok)
            return;
        root.windows = snap.windows || [];
        root.currentDesktop = snap.currentDesktop || 0;
        root.activeWindowId = snap.activeWindow || "";
        const names = snap.desktopNames || [];
        const count = Math.max(snap.numDesktops || names.length || 1, 1);
        const result = [];
        for (let i = 0; i < count; i++) {
            const wins = root.windows.filter(w => w.desktop === i);
            result.push({
                "index": i,
                "name": names[i] || String(i + 1),
                "windowCount": wins.length,
                "occupied": wins.length > 0,
                "urgent": wins.some(w => w.demandsAttention)
            });
        }
        root.desktops = result;
        root.ready = true;
        // Mirror upstream: a fullscreen app dismisses the modal drawers.
        if (root.hasFullscreen)
            ShellState.closeDrawers();
    }

    Process {
        id: poll
        command: ["python3", Config.scriptsDir + "/ewmh-state.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applySnapshot(JSON.parse(text.trim()));
                } catch (e) {
                    console.warn("caelestia-xfce: bad EWMH snapshot:", e);
                }
            }
        }
    }

    // Event-driven refresh: xprop -spy emits a line on every root-window
    // PropertyNotify for the atoms we care about (desktop switch, focus
    // change, window open/close) — the closest X11 gets to Hyprland's
    // event socket. Debounced because xfwm4 updates several atoms at once.
    Process {
        id: spy
        running: true
        command: ["xprop", "-root", "-spy",
            "_NET_CURRENT_DESKTOP", "_NET_ACTIVE_WINDOW", "_NET_CLIENT_LIST",
            "_NET_NUMBER_OF_DESKTOPS", "_NET_DESKTOP_NAMES"]
        stdout: SplitParser {
            onRead: data => spyDebounce.restart()
        }
        onExited: spyRestart.restart()
    }

    Timer {
        id: spyRestart
        interval: 1000
        onTriggered: spy.running = true
    }

    Timer {
        id: spyDebounce
        interval: 60
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshSoon
        interval: 120
        onTriggered: root.refresh()
    }

    // Safety net (title changes etc. do not hit root properties).
    Timer {
        interval: Config.ewmhPollMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // `qs -c caelestia-xfce ipc call wm switchDesktop 2` — handy from
    // xfwm4 custom shortcuts / sxhkd.
    IpcHandler {
        target: "wm"

        function switchDesktop(index: int): void {
            root.switchDesktop(index);
        }
        function nextDesktop(): void {
            root.relativeDesktop(1);
        }
        function prevDesktop(): void {
            root.relativeDesktop(-1);
        }
        function closeActive(): void {
            if (root.activeWindowId)
                root.closeWindow(root.activeWindowId);
        }
    }
}
