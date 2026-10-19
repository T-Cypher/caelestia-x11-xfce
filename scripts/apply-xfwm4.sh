#!/usr/bin/env bash
# xfwm4 tuning for caelestia-xfce: built-in compositor on (real alpha for
# the drawers/OSD/notifications), flat frames (no blur exists on xfwm4 —
# see PORTING.md), shadows that don't fight the dock-type bar, and the
# bundled Caelestia-Xfce window decoration theme when installed.
set -u

xq() { # xq <channel> <property> <value>
    local channel=$1 prop=$2 value=$3 type=string
    case $value in
        true|false) type=bool ;;
        ''|*[!0-9-]*) type=string ;;
        *) type=int ;;
    esac
    if ! xfconf-query -c "$channel" -p "$prop" -s "$value" 2>/dev/null; then
        xfconf-query -c "$channel" -p "$prop" -n -t "$type" -s "$value"
    fi
    printf '  %s %s = %s\n' "$channel" "$prop" "$value"
}

[[ -n ${DISPLAY:-} ]] || { echo "apply-xfwm4: no \$DISPLAY, run me inside the Xfce session" >&2; exit 1; }
command -v xfconf-query >/dev/null || { echo "apply-xfwm4: xfconf-query not found" >&2; exit 1; }

echo "caelestia-xfce: configuring xfwm4"

# Compositor (XRender) — gives us translucent surfaces + soft shadows.
xq xfwm4 /general/use_compositing        true
xq xfwm4 /general/show_frame_shadow      true
xq xfwm4 /general/show_popup_shadow      true
# No shadow under dock windows: the bar is _NET_WM_WINDOW_TYPE_DOCK.
xq xfwm4 /general/show_dock_shadow       false
# Keep frames opaque & flat: upstream relies on Hyprland blur, which
# xfwm4 cannot do; translucent titlebars would just look washed out.
xq xfwm4 /general/frame_opacity          100
xq xfwm4 /general/inactive_opacity       100
xq xfwm4 /general/move_opacity           90
xq xfwm4 /general/resize_opacity         90

# Decorations
if [[ -d $HOME/.themes/Caelestia-Xfce/xfwm4 ]]; then
    xq xfwm4 /general/theme              Caelestia-Xfce
else
    echo "  (Caelestia-Xfce xfwm4 theme not in ~/.themes — keeping your current theme)"
fi
xq xfwm4 /general/title_font             "Rubik Bold 10"
xq xfwm4 /general/button_layout          "O|HMC"
xq xfwm4 /general/title_alignment        left

# Workspace/focus preferences (wrap_workspaces, cycle_workspaces,
# scroll_workspaces, Alt+Tab mode, ...) are deliberately left alone:
# the shell reads whatever xfwm4 publishes via EWMH and its own
# bar-scroll wraps arithmetically, so it does not depend on them.

cat <<'EOF'

Done. The bar reserves its edge with _NET_WM_STRUT_PARTIAL, so please
leave xfwm4 "workspace margins" (Workspaces settings) at 0 — setting
both would reserve the space twice.
EOF
