pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// Volume / brightness / battery / network / lock-keys, plus the write
// side (pactl / brightnessctl). Upstream splits these into Audio.qml,
// Brightness.qml, Nmcli.qml etc. on top of PipeWire/UPower D-Bus
// services; the XFCE port probes the same CLI tools xfce4's own panel
// plugins shell out to, so a minimal X11-only Quickshell build suffices.
Singleton {
    id: root

    property real volume: -1        // -1 = unknown, else 0..Config.maxVolume
    property bool muted: false
    property real brightness: -1    // -1 = no controllable backlight
    property bool batteryPresent: false
    property int batteryPercent: -1
    property bool batteryCharging: false
    property string networkType: "none"   // none | wifi | wired
    property string networkName: ""
    property bool capsLock: false
    property bool numLock: false
    property string kbLayout: ""
    property real cpuPercent: 0
    property real memPercent: 0
    property string userName: ""
    property string hostName: ""

    readonly property string volumeIcon: muted || volume <= 0 ? "volume_off" : (volume < 0.5 ? "volume_down" : "volume_up")
    readonly property string networkIcon: networkType === "wifi" ? "wifi" : (networkType === "wired" ? "lan" : "wifi_off")
    readonly property string batteryIcon: {
        if (batteryCharging)
            return "battery_charging_full";
        if (batteryPercent >= 90)
            return "battery_full";
        if (batteryPercent >= 60)
            return "battery_5_bar";
        if (batteryPercent >= 40)
            return "battery_3_bar";
        if (batteryPercent >= 15)
            return "battery_1_bar";
        return "battery_alert";
    }

    function setVolume(v) {
        const clamped = Math.max(0, Math.min(Config.maxVolume, v));
        root.volume = clamped;
        Quickshell.execDetached(["pactl", "set-sink-volume", "@DEFAULT_SINK@", Math.round(clamped * 100) + "%"]);
        ShellState.showOsd(root.volumeIcon, "Volume", Math.min(clamped, 1));
        refreshSoon.restart();
    }

    function changeVolume(delta) {
        if (root.volume >= 0)
            setVolume(root.volume + delta);
    }

    function toggleMute() {
        root.muted = !root.muted;
        Quickshell.execDetached(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"]);
        ShellState.showOsd(root.volumeIcon, root.muted ? "Muted" : "Volume", Math.max(Math.min(root.volume, 1), 0));
        refreshSoon.restart();
    }

    function setBrightness(v) {
        const clamped = Math.max(0.05, Math.min(1, v));
        root.brightness = clamped;
        Quickshell.execDetached(["brightnessctl", "set", Math.round(clamped * 100) + "%"]);
        ShellState.showOsd("brightness_medium", "Brightness", clamped);
        refreshSoon.restart();
    }

    function changeBrightness(delta) {
        if (root.brightness >= 0)
            setBrightness(root.brightness + delta);
    }

    function refresh() {
        if (!poll.running)
            poll.running = true;
    }

    Process {
        id: poll
        command: ["python3", Config.scriptsDir + "/sys-state.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                let snap;
                try {
                    snap = JSON.parse(text.trim());
                } catch (e) {
                    return;
                }
                if (!snap || !snap.ok)
                    return;
                if (snap.volume !== null && snap.volume !== undefined)
                    root.volume = snap.volume;
                root.muted = !!snap.muted;
                if (snap.brightness !== null && snap.brightness !== undefined)
                    root.brightness = snap.brightness;
                root.batteryPresent = !!(snap.battery && snap.battery.present);
                root.batteryPercent = root.batteryPresent ? snap.battery.percent : -1;
                root.batteryCharging = root.batteryPresent && !!snap.battery.charging;
                root.networkType = (snap.network && snap.network.type) || "none";
                root.networkName = (snap.network && snap.network.name) || "";
                root.capsLock = !!snap.capsLock;
                root.numLock = !!snap.numLock;
                root.kbLayout = snap.kbLayout || "";
                root.cpuPercent = snap.cpuPercent || 0;
                root.memPercent = snap.memPercent || 0;
                root.userName = snap.user || "";
                root.hostName = snap.host || "";
            }
        }
    }

    Timer {
        id: refreshSoon
        interval: 180
        onTriggered: root.refresh()
    }

    Timer {
        interval: Config.sysPollMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // Bound from xfwm4 multimedia keys (see scripts/apply-keybinds.sh):
    IpcHandler {
        target: "sys"

        function volumeUp(): void {
            root.changeVolume(Config.volumeStep);
        }
        function volumeDown(): void {
            root.changeVolume(-Config.volumeStep);
        }
        function mute(): void {
            root.toggleMute();
        }
        function brightnessUp(): void {
            root.changeBrightness(0.05);
        }
        function brightnessDown(): void {
            root.changeBrightness(-0.05);
        }
    }
}
