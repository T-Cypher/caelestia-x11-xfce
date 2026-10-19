#!/usr/bin/env bash
# Live smoke test: real X server (Xvfb) + real xfwm4 + real Quickshell,
# running this repo's shell end-to-end. Takes a screenshot with scrot.
#
# Needs: Xvfb xfwm4 qs wmctrl xdotool xterm scrot dbus-run-session
# Run from the repo root:  bash tests/xvfb-smoke.sh
# Screenshot lands in /tmp/caelestia-xfce-xvfb.png, shell log in /tmp/qs-shell.log
set -u

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
OUTER_HOME="$HOME"
TEST_HOME=/tmp/qstest-home
export HOME="$TEST_HOME"
export XDG_CONFIG_HOME="$TEST_HOME/.config"
export XDG_STATE_HOME="$TEST_HOME/.local/state"
export XDG_CACHE_HOME="$TEST_HOME/.cache"
export XDG_RUNTIME_DIR="$TEST_HOME/run"
export QT_QPA_PLATFORM=xcb

rm -rf "$TEST_HOME"
mkdir -p "$XDG_CONFIG_HOME/quickshell" "$XDG_STATE_HOME/caelestia-xfce"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"
cp -r "$REPO/quickshell/caelestia-xfce" "$XDG_CONFIG_HOME/quickshell/"

# Borrow the caller's fonts (Material Symbols/Rubik) if present, so icon
# ligatures render as icons instead of words in the screenshots.
if [[ -d $OUTER_HOME/.local/share/fonts ]]; then
    mkdir -p "$TEST_HOME/.local/share/fonts"
    cp "$OUTER_HOME"/.local/share/fonts/*.ttf "$TEST_HOME/.local/share/fonts/" 2>/dev/null || true
    fc-cache -f "$TEST_HOME/.local/share/fonts" >/dev/null 2>&1 || true
    echo "fonts in test home: $(ls "$TEST_HOME/.local/share/fonts" 2>/dev/null | tr '\n' ' ')"
fi

fail() { echo "SMOKE-FAIL: $*" >&2; exit 1; }
command -v Xvfb   >/dev/null || fail "Xvfb not installed"
command -v xfwm4  >/dev/null || fail "xfwm4 not installed"
command -v qs     >/dev/null || fail "quickshell (qs) not installed"

# Keep the outer script's env: dbus-run-session inherits it.
dbus-run-session -- bash <<'EOS'
set -u
cleanup() {
    pkill -x qs 2>/dev/null
    pkill -x quickshell 2>/dev/null
    pkill -x xfwm4 2>/dev/null
    pkill -x xclock 2>/dev/null
    pkill -x xterm 2>/dev/null
    pkill -f 'Xvfb :99' 2>/dev/null
}
trap cleanup EXIT

Xvfb :99 -screen 0 1280x800x24 >/tmp/xvfb.log 2>&1 &
sleep 1
export DISPLAY=:99

xfwm4 >/tmp/xfwm4.log 2>&1 &
for i in $(seq 1 30); do wmctrl -m >/dev/null 2>&1 && break; sleep 0.3; done
echo "window manager: $(wmctrl -m | head -2 | tr '\n' ' ')"
xsetroot -solid '#2a2a30'

xterm -geometry 80x24+140+90 -title 'caelestia test terminal' -e bash -c 'echo caelestia-xfce smoke test; sleep 30' >/tmp/xterm.log 2>&1 &
xclock -geometry 160x160+750+120 >/tmp/xclock.log 2>&1 &
sleep 1

qs -c caelestia-xfce >/tmp/qs-shell.log 2>&1 &
QS_PID=$!
sleep 6
if kill -0 "$QS_PID" 2>/dev/null; then
    echo "qs alive after 6s (pid $QS_PID)"
else
    echo "qs DIED — log:"; cat /tmp/qs-shell.log; exit 1
fi

echo "--- windows (wmctrl -lG) ---"; wmctrl -lG
echo "--- root EWMH ---"
xprop -root _NET_CURRENT_DESKTOP _NET_NUMBER_OF_DESKTOPS _NET_ACTIVE_WINDOW | head -5
echo "--- ewmh-state.py against the live X server ---"
python3 ~/.config/quickshell/caelestia-xfce/scripts/ewmh-state.py | python3 -m json.tool | head -34

echo "--- ipc: nextDesktop ---"; qs -c caelestia-xfce ipc call wm nextDesktop; sleep 0.8
xprop -root _NET_CURRENT_DESKTOP
qs -c caelestia-xfce ipc call wm switchDesktop 0; sleep 0.6
echo "--- ipc: open launcher ---"; qs -c caelestia-xfce ipc call drawers toggle launcher; sleep 1
echo "--- notification ---"; notify-send -a SmokeTest 'caelestia-xfce' 'Notifications work on X11' 2>/dev/null; sleep 1
echo "--- windows after launcher+notification (drawer should be a quickshell window at x=66) ---"
wmctrl -lG

shot() { # shot <name>
    rm -f "/tmp/caelestia-xfce-$1.png"
    scrot --overwrite "/tmp/caelestia-xfce-$1.png" 2>/dev/null || scrot "/tmp/caelestia-xfce-$1.png"
    echo "screenshot: /tmp/caelestia-xfce-$1.png"
}
shot xvfb

echo "--- ipc: dashboard ---"; qs -c caelestia-xfce ipc call drawers open dashboard; sleep 1
shot dashboard
echo "--- ipc: session ---"; qs -c caelestia-xfce ipc call drawers open session; sleep 1
shot session
qs -c caelestia-xfce ipc call drawers close; sleep 0.3
echo "--- qs log ---"; cat /tmp/qs-shell.log
echo "SMOKE-OK"
EOS
