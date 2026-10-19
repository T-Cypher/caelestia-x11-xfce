#!/usr/bin/env bash
# caelestia-xfce installer (Arch Linux + Xfce on X11).
#
#   ./install.sh                 full install, replace xfce4-panel, start now
#   ./install.sh --check         verify the environment, change nothing
#   ./install.sh --skip-packages I already installed the dependencies
#   ./install.sh --no-keybinds   don't touch xfce4-keyboard-shortcuts
#   ./install.sh --no-start      install only (starts at next login)
#
# Everything user-modifying is backed up under
# ~/.local/state/caelestia-xfce/backup-<timestamp>/ and uninstall.sh
# reverses it (see README > Uninstall).
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
QS_DEST="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/caelestia-xfce"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia-xfce"
BACKUP_DIR="$STATE_DIR/backup-$(date +%Y%m%d-%H%M%S)"
AUTOSTART_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
BIN_DIR="$HOME/.local/bin"
THEME_DEST="$HOME/.themes/Caelestia-Xfce"

SKIP_PACKAGES=0 NO_KEYBINDS=0 NO_START=0 CHECK_ONLY=0
for arg in "$@"; do
    case $arg in
        --skip-packages) SKIP_PACKAGES=1 ;;
        --no-keybinds)   NO_KEYBINDS=1 ;;
        --no-start)      NO_START=1 ;;
        --check)         CHECK_ONLY=1 ;;
        -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
        *) echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
    esac
done

log()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

backup() { # backup <path>
    [[ -e $1 ]] || return 0
    mkdir -p "$BACKUP_DIR"
    cp -a "$1" "$BACKUP_DIR/$(basename "$1").bak-$(date +%s%N)"
}

aur_helper() {
    for h in paru yay; do
        command -v "$h" >/dev/null && { printf '%s\n' "$h"; return 0; }
    done
    return 1
}

# ---------------------------------------------------------------------------
if [[ $CHECK_ONLY == 1 ]]; then
    log "caelestia-xfce environment check"
    fail=0
    check() {
        if command -v "$1" >/dev/null; then printf '  ok   %s\n' "$1"
        else printf '  MISS %s  (%s)\n' "$1" "${2:-}"; fail=1; fi
    }
    check qs "quickshell / quickshell-git"
    check python3
    check wmctrl "EWMH window actions"
    check xdotool "minimize"
    check xprop "EWMH state + event spy"
    check xset "caps/num lock"
    check pactl "volume (libpulse / pipewire-pulse)"
    check brightnessctl "backlight (optional on desktops)"
    check gtk-launch "pinned apps (gtk3)"
    check xfconf-query "Xfce settings"
    check xfce4-session-logout "session actions"
    check xflock4 "screen lock"
    python3 -m py_compile "$REPO_DIR/quickshell/caelestia-xfce/scripts/"*.py \
        && printf '  ok   python helpers compile\n' || fail=1
    if fc-list 2>/dev/null | grep -qi "Material Symbols"; then
        printf '  ok   Material Symbols font\n'
    else
        printf '  MISS Material Symbols font (icons will show as words)\n'; fail=1
    fi
    if [[ -n ${DISPLAY:-} ]]; then
        printf '  wm:  %s\n' "$(wmctrl -m 2>/dev/null | sed -n 's/^Name: //p' || echo unknown)"
        xprop -root _NET_SUPPORTING_WM_CHECK >/dev/null 2>&1 \
            && printf '  ok   EWMH _NET_SUPPORTING_WM_CHECK present\n' \
            || { printf '  MISS EWMH support check\n'; fail=1; }
    else
        printf '  note no $DISPLAY — run the check inside the Xfce session too\n'
    fi
    [[ $fail == 0 ]] && log "all checks passed" || warn "some checks failed (see above)"
    exit "$fail"
fi

# ---------------------------------------------------------------------------
if [[ $SKIP_PACKAGES == 0 ]]; then
    command -v pacman >/dev/null || die "package installation targets Arch (pacman not found). Re-run with --skip-packages after installing dependencies yourself (see README.md)."
    log "Installing runtime dependencies (Arch packages)"
    SUDO=""
    [[ $EUID -ne 0 ]] && SUDO="sudo"
    $SUDO pacman -S --needed --noconfirm \
        wmctrl xdotool xorg-xprop xorg-xset brightnessctl libpulse \
        networkmanager nm-connection-editor gtk3 python \
        xfwm4 xfce4-session xfce4-settings xfce4-terminal thunar mousepad \
        xfce4-screenshooter xfce4-taskmanager xfce4-power-manager \
        ttf-jetbrains-mono-nerd

    if ! command -v qs >/dev/null; then
        if pacman -Si quickshell >/dev/null 2>&1; then
            $SUDO pacman -S --needed --noconfirm quickshell
        elif HELPER=$(aur_helper); then
            log "Installing quickshell-git from the AUR with $HELPER"
            "$HELPER" -S --needed --noconfirm quickshell-git
        else
            die "quickshell not in repos and no AUR helper (paru/yay) found.
       Install one, then: paru -S quickshell-git  — and re-run with --skip-packages."
        fi
    fi

    if ! fc-list 2>/dev/null | grep -qi "Material Symbols"; then
        if HELPER=$(aur_helper); then
            "$HELPER" -S --needed --noconfirm ttf-material-symbols-variable ttf-rubik-vf || true
        fi
    fi
    if ! fc-list 2>/dev/null | grep -qi "Material Symbols"; then
        warn "Material Symbols font still missing — downloading user copies from Google Fonts upstream"
        FONT_DIR="$HOME/.local/share/fonts"
        mkdir -p "$FONT_DIR"
        curl -fL --retry 2 -o "$FONT_DIR/MaterialSymbolsRounded.ttf" \
            "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" \
            || warn "font download failed; bar icons will render as text until the font is installed"
        curl -fL --retry 2 -o "$FONT_DIR/Rubik.ttf" \
            "https://github.com/google/fonts/raw/main/ofl/rubik/Rubik%5Bwght%5D.ttf" || true
        fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
    fi
fi

command -v qs >/dev/null || die "qs (quickshell) still not on PATH — aborting before touching your session"

# ---------------------------------------------------------------------------
log "Installing Quickshell config to $QS_DEST"
backup "$QS_DEST"
mkdir -p "$QS_DEST"
cp -a "$REPO_DIR/quickshell/caelestia-xfce/." "$QS_DEST/"
chmod +x "$QS_DEST/scripts/"*.py

log "Installing session wrapper and tools to $BIN_DIR"
mkdir -p "$BIN_DIR"
install -Dm755 "$REPO_DIR/scripts/caelestia-xfce-session.sh" "$BIN_DIR/caelestia-xfce-session"
install -Dm755 "$REPO_DIR/scripts/apply-keybinds.sh"         "$BIN_DIR/caelestia-xfce-apply-keybinds"
install -Dm755 "$REPO_DIR/scripts/apply-xfwm4.sh"            "$BIN_DIR/caelestia-xfce-apply-xfwm4"

log "Installing autostart entry"
backup "$AUTOSTART_DIR/caelestia-xfce.desktop"
mkdir -p "$AUTOSTART_DIR"
sed "s|^Exec=.*|Exec=$BIN_DIR/caelestia-xfce-session|" \
    "$REPO_DIR/autostart/caelestia-xfce.desktop" >"$AUTOSTART_DIR/caelestia-xfce.desktop"

log "Masking xfce4-notifyd autostart (Quickshell owns org.freedesktop.Notifications)"
backup "$AUTOSTART_DIR/xfce4-notifyd.desktop"
NOTIFY_SRC=""
for cand in /etc/xdg/autostart/xfce4-notifyd.desktop \
            "${XDG_CONFIG_DIRS:-/etc/xdg}/autostart/xfce4-notifyd.desktop"; do
    [[ -f $cand ]] && NOTIFY_SRC=$cand && break
done
if [[ -n $NOTIFY_SRC ]]; then
    cp "$NOTIFY_SRC" "$AUTOSTART_DIR/xfce4-notifyd.desktop"
else
    cat >"$AUTOSTART_DIR/xfce4-notifyd.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Xfce Notification Daemon (masked by caelestia-xfce)
Exec=/usr/lib/xfce4/notifyd/xfce4-notifyd
EOF
fi
cat >>"$AUTOSTART_DIR/xfce4-notifyd.desktop" <<'EOF'
Hidden=true
X-Caelestia-Xfce-Masked=true
EOF

log "Installing xfwm4 theme to $THEME_DEST"
backup "$THEME_DEST"
mkdir -p "$THEME_DEST"
cp -a "$REPO_DIR/xfwm4/Caelestia-Xfce/." "$THEME_DEST/"

mkdir -p "$STATE_DIR"
printf 'installed=%s\nbackup=%s\nrepo=%s\n' "$(date -Iseconds)" "$BACKUP_DIR" "$REPO_DIR" >"$STATE_DIR/install-info.txt"

# ---------------------------------------------------------------------------
if [[ -n ${DISPLAY:-} ]]; then
    log "Applying xfwm4 settings"
    "$REPO_DIR/scripts/apply-xfwm4.sh" || warn "xfwm4 settings not applied (run caelestia-xfce-apply-xfwm4 inside the session)"
    if [[ $NO_KEYBINDS == 0 ]]; then
        log "Applying keyboard shortcuts"
        "$REPO_DIR/scripts/apply-keybinds.sh" || warn "keybinds not applied (run caelestia-xfce-apply-keybinds inside the session)"
    fi
    if [[ $NO_START == 0 ]]; then
        log "Starting the shell now (this quits xfce4-panel)"
        setsid nohup "$BIN_DIR/caelestia-xfce-session" >/dev/null 2>&1 &
        sleep 1
    fi
else
    warn "no \$DISPLAY: session settings skipped — they apply on next graphical login,"
    warn "or run inside Xfce: caelestia-xfce-apply-xfwm4 && caelestia-xfce-apply-keybinds"
fi

cat <<EOF

$(log "Done.")
  Launcher:    Super+Space        Dashboard: Super+D
  Session:     Super+Shift+S      Close app: Super+Q
  Log:         $STATE_DIR/shell.log
  Backups:     $BACKUP_DIR
  Config:      $QS_DEST/services/Config.qml   (live-reloads)
  Get xfce4-panel back temporarily:  qs -c caelestia-xfce kill; xfce4-panel &
  Permanent removal:                 ./uninstall.sh
EOF
