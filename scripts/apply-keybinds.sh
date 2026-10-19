#!/usr/bin/env bash
# Global shortcuts for caelestia-xfce.
#
# Upstream registers these with Hyprland's global-shortcuts protocol
# (modules/Shortcuts.qml). On X11 there is no such protocol, so we use
# Xfce's own custom-command shortcuts (xfconf channel
# xfce4-keyboard-shortcuts) that call Quickshell IPC. Desktop numbers,
# Alt+Tab, tiling keys etc. stay with xfwm4's own bindings.
#
# Re-runnable. Previous values are recorded once in
# ~/.local/state/caelestia-xfce/keybinds-backup.tsv so uninstall.sh can
# put your old bindings back.
set -u

CHANNEL="xfce4-keyboard-shortcuts"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia-xfce"
BACKUP="$STATE_DIR/keybinds-backup.tsv"
mkdir -p "$STATE_DIR"
touch "$BACKUP"

QSIPC="qs -c caelestia-xfce ipc call"

set_cmd() {
    local key=$1 cmd=$2 existing
    if ! grep -qF "$(printf '%s\t' "$key")" "$BACKUP"; then
        existing=$(xfconf-query -c "$CHANNEL" -p "/commands/custom/$key" 2>/dev/null || true)
        printf '%s\t%s\n' "$key" "${existing:-__MISSING__}" >>"$BACKUP"
    fi
    if ! xfconf-query -c "$CHANNEL" -p "/commands/custom/$key" -s "$cmd" 2>/dev/null; then
        xfconf-query -c "$CHANNEL" -p "/commands/custom/$key" -n -t string -s "$cmd"
    fi
    printf '  %-28s -> %s\n' "$key" "$cmd"
}

[[ -n ${DISPLAY:-} ]] || { echo "apply-keybinds: no \$DISPLAY, run me inside the Xfce session" >&2; exit 1; }
command -v xfconf-query >/dev/null || { echo "apply-keybinds: xfconf-query not found" >&2; exit 1; }

echo "caelestia-xfce: installing keyboard shortcuts (backup: $BACKUP)"
set_cmd "<Super>space"                "$QSIPC drawers toggle launcher"
set_cmd "<Super>d"                    "$QSIPC drawers toggle dashboard"
set_cmd "<Super><Shift>s"             "$QSIPC drawers toggle session"
set_cmd "<Super>q"                    "$QSIPC wm closeActive"
set_cmd "<Super>t"                    "xfce4-terminal"
set_cmd "<Super>e"                    "thunar"
set_cmd "<Super>w"                    "firefox"
set_cmd "XF86AudioRaiseVolume"       "$QSIPC sys volumeUp"
set_cmd "XF86AudioLowerVolume"       "$QSIPC sys volumeDown"
set_cmd "XF86AudioMute"              "$QSIPC sys mute"
set_cmd "XF86MonBrightnessUp"        "$QSIPC sys brightnessUp"
set_cmd "XF86MonBrightnessDown"      "$QSIPC sys brightnessDown"
set_cmd "<Super><Shift>Print"        "xfce4-screenshooter -r"

cat <<'EOF'

Notes:
  * Super+1..9 workspace switching is handled natively by xfwm4
    (Settings > Window Manager > Keyboard) and is left untouched.
  * For a single tap of Super to open the launcher (upstream style):
      sudo pacman -S xcape
      CAELESTIA_XFCE_SUPER_TAP=1 caelestia-xfce-session --restart-shell
  * If Super+Space is already your keyboard-layout switch, edit the
    first binding above and re-run this script.
EOF
