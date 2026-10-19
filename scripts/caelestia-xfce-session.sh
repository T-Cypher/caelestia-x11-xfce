#!/usr/bin/env bash
# caelestia-xfce session launcher.
#
# Installed to ~/.local/bin/caelestia-xfce-session and started from
# ~/.config/autostart/caelestia-xfce.desktop at Xfce login.
# It replaces xfce4-panel + xfce4-notifyd with the Quickshell shell:
#   * xfce4-panel       -> killed (bar talks EWMH struts to xfwm4 instead)
#   * xfce4-notifyd     -> killed (single owner of org.freedesktop.Notifications)
set -u

export QT_QPA_PLATFORM=xcb
export CAELESTIA_XFCE_SCRIPTS="${CAELESTIA_XFCE_SCRIPTS:-$HOME/.config/quickshell/caelestia-xfce/scripts}"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia-xfce"
mkdir -p "$STATE_DIR"

die() { printf 'caelestia-xfce: %s\n' "$*" >&2; exit 1; }

# Restart path used by the in-shell "Restart shell" button.
if [[ ${1:-} == "--restart-shell" ]]; then
    qs -c caelestia-xfce kill >/dev/null 2>&1 || true
    sleep 0.4
    exec "$0"
fi

[[ -n ${DISPLAY:-} ]] || die "no \$DISPLAY — this shell needs an X11 session"
command -v qs >/dev/null || die "quickshell (qs) not found; see README install steps"

# Already running? Don't start a second instance.
if pgrep -f "qs -c caelestia-xfce" >/dev/null 2>&1; then
    exit 0
fi

# Warn (but carry on) if the window manager is not xfwm4.
if command -v wmctrl >/dev/null; then
    WM_NAME=$(wmctrl -m 2>/dev/null | sed -n 's/^Name: //p' | head -n1)
    if [[ -n $WM_NAME && $WM_NAME != "Xfwm4" ]]; then
        printf 'caelestia-xfce: window manager is %q, not Xfwm4 — EWMH features may differ\n' "$WM_NAME" >&2
    fi
fi

# Replace panel + notification daemon (set CAELESTIA_XFCE_REPLACE_PANEL=0
# to keep xfce4-panel running alongside for a first test).
if [[ ${CAELESTIA_XFCE_REPLACE_PANEL:-1} == "1" ]]; then
    pkill -x xfce4-panel >/dev/null 2>&1 || true
    pkill -x xfce4-notifyd >/dev/null 2>&1 || true
fi

# Optional: single-tap Super opens the launcher (upstream behaviour).
# X11 has no compositor "Super on release" bind, so xcape maps a tap to
# Super+Space, which apply-keybinds.sh binds to the launcher.
if [[ ${CAELESTIA_XFCE_SUPER_TAP:-0} == "1" ]] && command -v xcape >/dev/null; then
    pgrep -x xcape >/dev/null || xcape -e 'Super_L=Super_L|space' >/dev/null 2>&1 &
fi

# Foreground under xfce4-session's autostart supervision; log for debugging.
exec qs -c caelestia-xfce >>"$STATE_DIR/shell.log" 2>&1
