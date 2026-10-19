#!/usr/bin/env python3
"""Offline tests for the caelestia-xfce probe scripts.

No X server needed: fake `xprop`, `pactl`, `brightnessctl`, `nmcli`,
`xset` and `setxkbmap` executables are generated in a temp dir and put
first on PATH, then the real probe scripts are run against them.

    python3 tests/test_probes.py
"""

import json
import os
import stat
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(ROOT, "quickshell", "caelestia-xfce", "scripts")

FAKE_XPROP = r'''#!/usr/bin/env python3
import sys

args = sys.argv[1:]
if "-spy" in args:
    print("_NET_ACTIVE_WINDOW: window id # 0x2a00007")
    sys.exit(0)

WINDOWS = {
    "0x2a00007": [
        '_NET_WM_NAME(UTF8_STRING) = "GitHub — Mozilla Firefox"',
        'WM_CLASS(STRING) = "Navigator", "firefox"',
        "_NET_WM_DESKTOP(CARDINAL) = 1",
        "_NET_WM_STATE(ATOM) = ",
        "_NET_WM_WINDOW_TYPE(ATOM) = _NET_WM_WINDOW_TYPE_NORMAL",
        "_NET_WM_PID(CARDINAL) = 4242",
    ],
    "0x2c00003": [
        '_NET_WM_NAME(UTF8_STRING) = "user@host: ~"',
        'WM_CLASS(STRING) = "xfce4-terminal", "Xfce4-terminal"',
        "_NET_WM_DESKTOP(CARDINAL) = 0",
        "_NET_WM_STATE(ATOM) = _NET_WM_STATE_HIDDEN, _NET_WM_STATE_DEMANDS_ATTENTION",
        "_NET_WM_WINDOW_TYPE(ATOM) = _NET_WM_WINDOW_TYPE_NORMAL",
        "_NET_WM_PID(CARDINAL) = 4243",
    ],
    "0x2e00001": [  # a dock (the shell bar itself) — must be filtered out
        '_NET_WM_NAME(UTF8_STRING) = "quickshell"',
        'WM_CLASS(STRING) = "quickshell", "quickshell"',
        "_NET_WM_DESKTOP(CARDINAL) = 4294967295",
        "_NET_WM_STATE(ATOM) = _NET_WM_STATE_SKIP_TASKBAR",
        "_NET_WM_WINDOW_TYPE(ATOM) = _NET_WM_WINDOW_TYPE_DOCK",
        "_NET_WM_PID(CARDINAL) = 4244",
    ],
}

if "-root" in args:
    print("_NET_CURRENT_DESKTOP(CARDINAL) = 1")
    print("_NET_NUMBER_OF_DESKTOPS(CARDINAL) = 4")
    print("_NET_ACTIVE_WINDOW(WINDOW): window id # 0x2a00007")
    print("_NET_CLIENT_LIST(WINDOW): window id # 0x2c00003, 0x2a00007, 0x2e00001")
    print('_NET_DESKTOP_NAMES(UTF8_STRING) = "Web, Mail", "Code \\"main\\""')
    sys.exit(0)

if "-id" in args:
    wid = args[args.index("-id") + 1].lower()
    for line in WINDOWS.get(wid, []):
        print(line)
    sys.exit(0)
sys.exit(0)
'''

FAKES = {
    "xprop": FAKE_XPROP,
    "pactl": """#!/bin/sh
case "$1 $2" in
  "get-sink-volume @DEFAULT_SINK@") echo "Volume: front-left: 42598 /  65% / -11.18 dB,   front-right: 42598 /  65% / -11.18 dB" ;;
  "get-sink-mute @DEFAULT_SINK@") echo "Mute: no" ;;
esac
""",
    "brightnessctl": """#!/bin/sh
echo "intel_backlight,backlight,750,75%,1000"
""",
    "nmcli": """#!/bin/sh
echo "wifi:connected:HomeNet-5G"
echo "ethernet:unavailable:Wired"
echo "loopback:connected:lo"
""",
    "xset": """#!/bin/sh
echo "  auto repeat:  on    key click percent:  0    LED mask:  00000001"
echo "  XKB indicators:"
echo "    00: Caps Lock:   on     01: Num Lock:    off    02: Scroll Lock: off"
""",
    "setxkbmap": """#!/bin/sh
echo "rules:      evdev"
echo "model:      pc105"
echo "layout:     pt"
""",
}


def write_fake(bin_dir, name, body):
    path = os.path.join(bin_dir, name)
    with open(path, "w") as fh:
        fh.write(body)
    os.chmod(path, os.stat(path).st_mode | stat.S_IXUSR)


def run_probe(script, env):
    out = subprocess.run([sys.executable, os.path.join(SCRIPTS, script)],
                         capture_output=True, text=True, env=env, timeout=15)
    assert out.returncode == 0, f"{script} exited {out.returncode}: {out.stderr}"
    lines = [ln for ln in out.stdout.strip().splitlines() if ln.strip()]
    assert len(lines) == 1, f"{script} must print exactly one JSON line, got: {out.stdout!r}"
    return json.loads(lines[0])


def main():
    with tempfile.TemporaryDirectory() as tmp:
        for name, body in FAKES.items():
            write_fake(tmp, name, body)
        env = dict(os.environ)
        env["PATH"] = tmp + os.pathsep + env.get("PATH", "")

        ewmh = run_probe("ewmh-state.py", env)
        assert ewmh["ok"] is True, ewmh
        assert ewmh["currentDesktop"] == 1, ewmh
        assert ewmh["numDesktops"] == 4, ewmh
        # quoted name parsing: embedded comma + escaped quotes survive,
        # missing names are padded with numbers
        assert ewmh["desktopNames"] == ["Web, Mail", 'Code "main"', "3", "4"], ewmh
        assert ewmh["activeWindow"] == "0x2a00007", ewmh
        assert len(ewmh["windows"]) == 2, "dock window must be filtered: " + json.dumps(ewmh)
        by_id = {w["id"]: w for w in ewmh["windows"]}
        firefox = by_id["0x2a00007"]
        assert firefox["wmClass"] == "firefox" and firefox["desktop"] == 1, firefox
        assert firefox["title"].startswith("GitHub"), firefox
        term = by_id["0x2c00003"]
        assert term["minimized"] is True and term["demandsAttention"] is True, term
        print("ewmh-state.py  OK:", json.dumps(ewmh)[:160], "...")

        sys_state = run_probe("sys-state.py", env)
        assert sys_state["ok"] is True, sys_state
        assert sys_state["volume"] == 0.65, sys_state
        assert sys_state["muted"] is False, sys_state
        assert sys_state["brightness"] == 0.75, sys_state
        assert sys_state["network"] == {"type": "wifi", "name": "HomeNet-5G"}, sys_state
        assert sys_state["capsLock"] is True and sys_state["numLock"] is False, sys_state
        assert sys_state["kbLayout"] == "PT", sys_state
        print("sys-state.py   OK:", json.dumps(sys_state)[:160], "...")

    # Probes must degrade to {"ok": false, ...} / nulls, never crash,
    # when the X tools are missing entirely (empty PATH except python dir).
    env = dict(os.environ)
    env["PATH"] = os.path.dirname(sys.executable)
    ewmh = run_probe("ewmh-state.py", env)
    assert ewmh["ok"] is False, ewmh
    sys_state = run_probe("sys-state.py", env)
    assert sys_state["ok"] is True and sys_state["volume"] is None, sys_state
    print("degradation    OK: probes survive missing tools")

    print("\nAll probe tests passed.")


if __name__ == "__main__":
    main()
