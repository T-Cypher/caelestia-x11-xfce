#!/usr/bin/env bash
# Remove caelestia-xfce and bring xfce4-panel / xfce4-notifyd back.
#
#   ./uninstall.sh                    interactive confirm
#   ./uninstall.sh --yes              no prompt
#   ./uninstall.sh --yes --restore-keybinds
#       also restore the pre-install values recorded by apply-keybinds.sh
set -u

QS_DEST="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia-xfce"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia-xfce"
AUTOSTART_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
BIN_DIR="$HOME/.local/bin"
THEME_DEST="$HOME/.themes/Caelestia-Xfce"

YES=0 RESTORE_KEYS=0
for arg in "$@"; do
    case $arg in
        --yes) YES=1 ;;
        --restore-keybinds) RESTORE_KEYS=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

if [[ $YES == 0 ]]; then
    read -r -p "Remove caelestia-xfce and restart xfce4-panel? [y/N] " reply
    [[ $reply =~ ^[Yy]$ ]] || { echo "aborted"; exit 0; }
fi

echo "==> Stopping the shell"
qs -c caelestia-xfce kill >/dev/null 2>&1 || true
pkill -f "qs -c caelestia-xfce" >/dev/null 2>&1 || true

echo "==> Removing files"
rm -f "$AUTOSTART_DIR/caelestia-xfce.desktop"
rm -f "$BIN_DIR/caelestia-xfce-session" \
      "$BIN_DIR/caelestia-xfce-apply-keybinds" \
      "$BIN_DIR/caelestia-xfce-apply-xfwm4"
rm -rf "$QS_DEST"
rm -rf "$THEME_DEST"

# Only remove the notifyd mask if it is ours.
if grep -q "X-Caelestia-Xfce-Masked=true" "$AUTOSTART_DIR/xfce4-notifyd.desktop" 2>/dev/null; then
    rm -f "$AUTOSTART_DIR/xfce4-notifyd.desktop"
    echo "    xfce4-notifyd autostart unmasked (back at next login/notification)"
fi

if [[ $RESTORE_KEYS == 1 && -f $STATE_DIR/keybinds-backup.tsv ]]; then
    echo "==> Restoring pre-install keyboard shortcuts"
    while IFS=$(printf '\t') read -r key value; do
        [[ -n $key ]] || continue
        if [[ $value == "__MISSING__" ]]; then
            xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/$key" -r 2>/dev/null || true
        else
            xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/$key" -s "$value" 2>/dev/null || true
        fi
    done <"$STATE_DIR/keybinds-backup.tsv"
fi

# xfwm4 theme: if it still points at our (now removed) theme, fall back.
if command -v xfconf-query >/dev/null; then
    current_theme=$(xfconf-query -c xfwm4 -p /general/theme 2>/dev/null || true)
    if [[ $current_theme == "Caelestia-Xfce" ]]; then
        xfconf-query -c xfwm4 -p /general/theme -s "Default" 2>/dev/null || true
        echo "    xfwm4 theme reset to Default"
    fi
fi

if [[ -n ${DISPLAY:-} ]] && command -v xfce4-panel >/dev/null; then
    echo "==> Restarting xfce4-panel"
    setsid nohup xfce4-panel >/dev/null 2>&1 &
fi

echo "Done. Backups kept in $STATE_DIR (delete manually when happy)."
