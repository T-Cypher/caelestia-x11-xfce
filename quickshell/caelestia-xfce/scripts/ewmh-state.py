#!/usr/bin/env python3
"""EWMH state snapshot for caelestia-xfce (the X11 replacement for
Hyprland IPC / `hyprctl -j clients`).

Reads everything xfwm4 publishes as root/per-window properties via
`xprop` and prints one JSON object to stdout:

  {"ok": true, "currentDesktop": 0, "numDesktops": 4,
   "desktopNames": ["1", "2", ...], "activeWindow": "0x2a00007",
   "windows": [{"id": "0x2a00007", "title": "..", "wmClass": "firefox",
                "desktop": 0, "type": "NORMAL", "minimized": false,
                "fullscreen": false, "sticky": false,
                "skipTaskbar": false, "demandsAttention": false, "pid": 1234}]}

Never raises: on failure prints {"ok": false, "error": "..."} so the QML
side can keep showing the last good snapshot instead of going blank.
Requires: xorg-xprop (base X11 tooling).
"""

import json
import re
import subprocess
import sys

ROOT_PROPS = [
    "_NET_CURRENT_DESKTOP", "_NET_NUMBER_OF_DESKTOPS", "_NET_ACTIVE_WINDOW",
    "_NET_CLIENT_LIST", "_NET_DESKTOP_NAMES",
]
WIN_PROPS = [
    "_NET_WM_NAME", "WM_NAME", "WM_CLASS", "_NET_WM_DESKTOP",
    "_NET_WM_STATE", "_NET_WM_WINDOW_TYPE", "_NET_WM_PID",
]

# Window types that must never appear in a task list / workspace icons.
SKIP_TYPES = {"DOCK", "DESKTOP", "NOTIFICATION", "TOOLTIP", "MENU",
              "DROPDOWN_MENU", "POPUP_MENU", "SPLASH", "UTILITY"}


def run(args, timeout=2.0):
    return subprocess.run(args, capture_output=True, text=True,
                          timeout=timeout).stdout


def value_after_equals(line):
    return line.split("=", 1)[1].strip() if "=" in line else ""


def unquote_all(text):
    """Extract every "..." string xprop-style, honouring backslash escapes."""
    out, buf, in_str, esc = [], [], False, False
    for ch in text:
        if esc:
            buf.append({"n": "\n", "t": "\t"}.get(ch, ch))
            esc = False
        elif in_str and ch == "\\":
            esc = True
        elif ch == '"':
            if in_str:
                out.append("".join(buf))
                buf = []
            in_str = not in_str
        elif in_str:
            buf.append(ch)
    return out


def parse_root():
    data = {"currentDesktop": 0, "numDesktops": 0, "desktopNames": [],
            "activeWindow": "", "clientList": []}
    out = run(["xprop", "-root"] + ROOT_PROPS)
    for line in out.splitlines():
        if line.startswith("_NET_CURRENT_DESKTOP"):
            m = re.search(r"=\s*(\d+)", line)
            if m:
                data["currentDesktop"] = int(m.group(1))
        elif line.startswith("_NET_NUMBER_OF_DESKTOPS"):
            m = re.search(r"=\s*(\d+)", line)
            if m:
                data["numDesktops"] = int(m.group(1))
        elif line.startswith("_NET_ACTIVE_WINDOW"):
            m = re.search(r"(0x[0-9a-fA-F]+)", line)
            if m and int(m.group(1), 16) != 0:
                data["activeWindow"] = m.group(1).lower()
        elif line.startswith("_NET_CLIENT_LIST("):
            data["clientList"] = [w.lower() for w in
                                  re.findall(r"0x[0-9a-fA-F]+", line)]
        elif line.startswith("_NET_DESKTOP_NAMES"):
            data["desktopNames"] = unquote_all(value_after_equals(line))
    return data


def parse_window(win_id):
    try:
        out = run(["xprop", "-id", win_id] + WIN_PROPS, timeout=1.0)
    except Exception:
        return None
    win = {"id": win_id, "title": "", "wmClass": "", "wmInstance": "",
           "desktop": 0, "type": "NORMAL", "minimized": False,
           "fullscreen": False, "sticky": False, "skipTaskbar": False,
           "demandsAttention": False, "pid": 0}
    for line in out.splitlines():
        if line.startswith("_NET_WM_NAME") or (line.startswith("WM_NAME") and not win["title"]):
            names = unquote_all(value_after_equals(line))
            if names:
                win["title"] = names[0]
        elif line.startswith("WM_CLASS"):
            parts = unquote_all(value_after_equals(line))
            if len(parts) >= 2:
                win["wmInstance"], win["wmClass"] = parts[0], parts[1]
            elif parts:
                win["wmClass"] = parts[0]
        elif line.startswith("_NET_WM_DESKTOP"):
            m = re.search(r"=\s*(\d+)", line)
            if m:
                raw = int(m.group(1))
                win["desktop"] = -1 if raw == 0xFFFFFFFF else raw
                win["sticky"] = raw == 0xFFFFFFFF
        elif line.startswith("_NET_WM_STATE"):
            states = value_after_equals(line)
            win["minimized"] = "_NET_WM_STATE_HIDDEN" in states
            win["fullscreen"] = "_NET_WM_STATE_FULLSCREEN" in states
            win["skipTaskbar"] = "_NET_WM_STATE_SKIP_TASKBAR" in states
            win["demandsAttention"] = "_NET_WM_STATE_DEMANDS_ATTENTION" in states
            if "_NET_WM_STATE_STICKY" in states:
                win["sticky"] = True
        elif line.startswith("_NET_WM_WINDOW_TYPE"):
            m = re.search(r"_NET_WM_WINDOW_TYPE_([A-Z_]+)", line)
            if m:
                win["type"] = m.group(1)
        elif line.startswith("_NET_WM_PID"):
            m = re.search(r"=\s*(\d+)", line)
            if m:
                win["pid"] = int(m.group(1))
    if win["type"] in SKIP_TYPES or win["skipTaskbar"]:
        return None
    if not win["title"] and not win["wmClass"]:
        return None
    return win


def main():
    try:
        root = parse_root()
        windows = [w for w in (parse_window(i) for i in root.pop("clientList")) if w]
        names = root["desktopNames"]
        count = root["numDesktops"] or len(names) or 1
        names = (names + [str(i + 1) for i in range(len(names), count)])[:count]
        print(json.dumps({"ok": True, "currentDesktop": root["currentDesktop"],
                          "numDesktops": count, "desktopNames": names,
                          "activeWindow": root["activeWindow"],
                          "windows": windows}, ensure_ascii=False))
    except Exception as exc:  # keep the shell alive on a bad snapshot
        print(json.dumps({"ok": False, "error": str(exc)}))
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
