#!/usr/bin/env python3
"""System snapshot for caelestia-xfce (volume / brightness / battery /
network / lock keys / cpu / mem), printed as one JSON object.

Deliberately built on the same CLI tools the XFCE stack already uses
(pactl, brightnessctl, nmcli, xset) instead of extra Quickshell service
plugins, so the shell runs against a minimal X11-only Quickshell build.
Every probe is optional: missing tools yield null, never a crash.
"""

import glob
import json
import os
import re
import socket
import subprocess
import sys
import time


def run(args, timeout=1.5):
    try:
        return subprocess.run(args, capture_output=True, text=True,
                              timeout=timeout).stdout
    except Exception:
        return ""


def volume():
    out = run(["pactl", "get-sink-volume", "@DEFAULT_SINK@"])
    m = re.search(r"(\d+)%", out)
    muted = "yes" in run(["pactl", "get-sink-mute", "@DEFAULT_SINK@"])
    return (int(m.group(1)) / 100.0 if m else None), muted


def brightness():
    out = run(["brightnessctl", "-m"]).strip().splitlines()
    if out:
        parts = out[0].split(",")
        for p in parts:
            if p.endswith("%"):
                try:
                    return int(p[:-1]) / 100.0
                except ValueError:
                    pass
    for dev in sorted(glob.glob("/sys/class/backlight/*")):
        try:
            cur = int(open(os.path.join(dev, "brightness")).read())
            top = int(open(os.path.join(dev, "max_brightness")).read())
            if top > 0:
                return cur / top
        except Exception:
            continue
    return None


def battery():
    for dev in sorted(glob.glob("/sys/class/power_supply/BAT*")):
        try:
            pct = int(open(os.path.join(dev, "capacity")).read())
            status = open(os.path.join(dev, "status")).read().strip()
            return {"present": True, "percent": pct,
                    "charging": status in ("Charging", "Full"),
                    "status": status}
        except Exception:
            continue
    return {"present": False, "percent": -1, "charging": False, "status": ""}


def network():
    out = run(["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "device", "status"])
    for line in out.splitlines():
        parts = line.split(":")
        if len(parts) >= 3 and parts[1] == "connected" and parts[0] != "loopback":
            kind = "wifi" if parts[0] == "wifi" else "wired"
            return {"type": kind, "name": parts[2]}
    return {"type": "none", "name": ""}


def lock_keys():
    out = run(["xset", "q"])
    caps = bool(re.search(r"Caps Lock:\s+on", out))
    num = bool(re.search(r"Num Lock:\s+on", out))
    return caps, num


def kb_layout():
    out = run(["setxkbmap", "-query"])
    m = re.search(r"layout:\s*(\S+)", out)
    return m.group(1).split(",")[0].upper() if m else ""


def cpu_percent(sample=0.15):
    def read():
        with open("/proc/stat") as fh:
            parts = [int(x) for x in fh.readline().split()[1:]]
        return sum(parts), parts[3] + (parts[4] if len(parts) > 4 else 0)
    try:
        total1, idle1 = read()
        time.sleep(sample)
        total2, idle2 = read()
        dt, di = total2 - total1, idle2 - idle1
        return round(100.0 * (1 - di / dt), 1) if dt > 0 else 0.0
    except Exception:
        return 0.0


def mem_percent():
    try:
        info = {}
        with open("/proc/meminfo") as fh:
            for line in fh:
                k, v = line.split(":", 1)
                info[k] = int(v.split()[0])
        used = info["MemTotal"] - info.get("MemAvailable", info["MemFree"])
        return round(100.0 * used / info["MemTotal"], 1)
    except Exception:
        return 0.0


def main():
    vol, muted = volume()
    caps, num = lock_keys()
    try:
        uptime = int(float(open("/proc/uptime").read().split()[0]))
    except Exception:
        uptime = 0
    print(json.dumps({
        "ok": True,
        "volume": vol, "muted": muted,
        "brightness": brightness(),
        "battery": battery(),
        "network": network(),
        "capsLock": caps, "numLock": num,
        "kbLayout": kb_layout(),
        "cpuPercent": cpu_percent(),
        "memPercent": mem_percent(),
        "uptimeSeconds": uptime,
        "user": os.environ.get("USER", ""),
        "host": socket.gethostname(),
    }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
