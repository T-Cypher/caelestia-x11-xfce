# Porting Caelestia to Xfce (xfwm4) on X11 — engineering notes

This document records how each piece of upstream Caelestia
(<https://github.com/caelestia-dots/caelestia> dotfiles +
<https://github.com/caelestia-dots/shell>) was mapped to X11/Xfce,
what had to change shape, and what cannot be ported at all. It is the
design contract for everything in this repository.

## Why a re-implementation, not a patch

The upstream shell is not a set of standalone QML widgets with a
Hyprland if-branch. Its core assumptions are Wayland-shaped:

1. **One full-screen layer-shell surface** (`modules/drawers`) hosts
   the bar and every drawer; an input `Region` mask decides which
   pixels are clickable, `WlrLayershell.layer`/keyboard-focus modes
   decide stacking and focus, and Hyprland layerrules add blur.
2. **All window/workspace state** flows from `Quickshell.Hyprland`
   (`services/Hypr.qml`): toplevels with live screencopy captures,
   per-monitor workspaces, special (scratchpad) workspaces, window
   tags, fullscreen flags, keyboard devices.
3. **A compiled QML plugin** (`Caelestia.*`: config model, blobs,
   images, app-database, fuzzy sorter…) is linked against Quickshell
   internals and used across almost every file.
4. **Global shortcuts** use the `hyprland-global-shortcuts-v1`
   protocol; **lock** uses `ext-session-lock-v1`; **idle** uses
   `ext-idle-notify`; **screenshots/area picking** use screencopy.

X11/xfwm4 offers a different, older contract: EWMH/NetWM hints on the
root window, `PropertyNotify` as the only event stream, dock windows
with struts instead of layers, focus decided by the WM, and no
compositor protocol for captures or secure locking. Every item above
therefore needs a substitute mechanism, not a compatibility shim —
patching `Hypr.qml` in place would still leave `WlrLayershell`
attached properties, the drawers mask model and the plugin types
unresolved at load time.

Quickshell itself **does** support X11: `PanelWindow` maps to
`_NET_WM_WINDOW_TYPE_DOCK` + `_NET_WM_STRUT_PARTIAL` with an internal
panel stack, so the bar/drawers/overlays model survives — that's the
foundation this port is built on¹.

## Mechanism mapping

| Concern | Upstream (Hyprland/Wayland) | This port (xfwm4/X11) | Fidelity |
|---|---|---|---|
| Bar window | layer-shell `Top`, exclusive zone | X11 `PanelWindow`, strut = bar width | Equivalent behaviour for maximised windows |
| Drawers surface | 1 full-screen layer surface + input regions | 1 dock `PanelWindow` per drawer, sized to content | No outside-click grab; focus is best-effort |
| Stacking over fullscreen | layer `Overlay` switch | Dock is above normal windows; drawers close when `_NET_WM_STATE_FULLSCREEN` appears on the current desktop | Games/video keep the screen; OSD/notifs may sit under a fullscreen app that raises itself above docks |
| Workspaces | Hyprland workspaces per monitor + specials | EWMH desktops, global across Xinerama screens | Special/scratchpad workspaces: **impossible** in xfwm4 |
| Window list | `Hyprland.toplevels` + screencopy preview | `_NET_CLIENT_LIST` + per-window `xprop` (WM_CLASS, title, state) | No thumbnails; icon = theme lookup by WM_CLASS |
| Focused window | `Hyprland.activeToplevel` | `_NET_ACTIVE_WINDOW` | Equivalent |
| Dispatch | Hyprland IPC socket | `wmctrl`/`xdotool` EWMH client messages | Equivalent for switch/raise/close/minimize/move |
| WM events | Hyprland event socket (`Hyprland.refresh*` on events) | `xprop -root -spy …` PropertyNotify stream, debounced, + 2.5 s safety-net poll | Slightly coarser (title-only changes wait for the poll) |
| Global shortcuts | `hyprland-global-shortcuts-v1` | Xfce custom commands (`xfconf-query`) → `qs ipc call`; Super-tap optionally via `xcape` | Keys are WM/session-owned, not shell-owned |
| Lock screen | `ext-session-lock-v1` QML lock | `xflock4` → your X screensaver (xfce4-screensaver/light-locker/xscreensaver) | Shell-drawn lock UI: **not secure/possible** as a dock window; delegated |
| Idle/inhibit | idle-notify + idle-inhibit protocols | Not ported; Xfce power manager owns DPMS/screensaver timers | Use `xfce4-power-manager` + `caffeine`-style inhibitors if needed |
| Notifications | Quickshell `NotificationServer` | Same | Must displace `xfce4-notifyd` (D-Bus name is exclusive) |
| System tray | Quickshell SNI `SystemTray` | Same | XEmbed legacy icons unbridged (xfce4-panel had a bridge; we don't) |
| Media | Quickshell MPRIS | Same | Identical |
| Audio | Quickshell PipeWire service | `pactl` (PulseAudio API) | Works on PulseAudio **and** pipewire-pulse; no per-app streams |
| Brightness | `brightnessctl`/ddcutil + monitors | `brightnessctl` single value | No per-monitor/DDC control |
| Network | NetworkManager D-Bus/nmcli | `nmcli` status only | Settings delegated to `nm-connection-editor` |
| Battery/UPower | Quickshell UPower service | `/sys/class/power_supply` | No charge history/forecast |
| Keyboard layout/locks | Hyprland devices IPC | `setxkbmap -query` + `xset q` | Display-only; switching stays with Xkb options/Xfce settings |
| Wallpaper | Layer background surface + CLI scheme extraction | xfdesktop keeps the job | Dashboard "wallpaper" cards not ported; scheme colours still load if caelestia-cli wrote `scheme.json` |
| Window frames | Hyprland decorations (Lua config) | Generated xfwm4 theme (`xfwm4/Caelestia-Xfce`) | No gaps/tiling rules — xfwm4 is a stacking WM |
| Terminal/editor defaults | `foot`/`codium` (Wayland) | `xfce4-terminal`/`mousepad` | `foot` cannot run on X11 at all |
| Animations | Custom spring/easing curves on layer surfaces | Short ease-out fades inside each window | No shared "morphing drawer" geometry across windows |
| Config | `~/.config/caelestia/shell.json` via plugin | `services/Config.qml` (live-reloads), same key names where applicable | Edit-and-save, no JSON overlay yet |

## File mapping (upstream shell → this repo)

| Upstream | Port | Notes |
|---|---|---|
| `shell.qml` | `shell.qml` | Drops Background/AreaPicker/Lock surfaces; per-screen bar `Variants`; `drawers` IPC |
| `services/Hypr.qml` | `services/Wm.qml` + `scripts/ewmh-state.py` | The core of the port |
| `services/Audio.qml`, `Brightness.qml`, `Nmcli.qml` | `services/Sys.qml` + `scripts/sys-state.py` | CLI probes; `sys` IPC for media keys |
| `services/Colours.qml` | `services/Colours.qml` | Same scheme values; flat alpha (`transparency` layer-construction removed — no blur to see through to) |
| `services/Time.qml` | `services/TimeService.qml` | Renamed: no `qmldir` aliasing, singleton name = file name |
| `services/Notifs.qml` | `services/Notifs.qml` | Popups only; history/sidebar not in MVP |
| `services/Players.qml` | used inline in `Dashboard.qml` | First playing MPRIS player |
| `modules/bar/*` | `modules/bar/{Bar,Workspaces,TaskList,Tray}.qml` | Popouts hover-cards not ported; task list added (xfce4-panel job) |
| `modules/drawers/*` | `components/DrawerWindow.qml` | One X11 window per drawer |
| `modules/launcher/*` | `modules/drawers/Launcher.qml` | DesktopEntries + local ranking; no scheme/wallpaper/calc plugins |
| `modules/dashboard/*` | `modules/drawers/Dashboard.qml` | Media/system/sliders; no weather/visualiser |
| `modules/session/*` | `modules/drawers/Session.qml` | `xfce4-session-logout`, `xflock4` |
| `modules/notifications/*` | `modules/overlays/NotifPopups.qml` | |
| `modules/osd/*` | `modules/overlays/Osd.qml` | Bottom-centre pill |
| `modules/lock/*`, `modules/background/*`, `modules/areapicker/*`, `modules/windowinfo/*`, `modules/nexus/*` | — | Delegated (lock, wallpaper), impossible (screencopy previews), or out of MVP scope (settings app) |
| `modules/Shortcuts.qml` | `scripts/apply-keybinds.sh` + IPC handlers | Shortcuts live in xfconf |
| `hypr/` (dotfiles repo) | `scripts/apply-xfwm4.sh` + `xfwm4/Caelestia-Xfce` | Compositor + decorations instead of blur/gaps/layerrules |
| `thunar/` (dotfiles) | unchanged upstream config still applies | Nothing X11-specific to change |

## Key implementation decisions

### EWMH state via a snapshot script, events via `xprop -spy`

`Wm.qml` does not parse `wmctrl -l` output (column-fragile with odd
titles). Instead `ewmh-state.py` reads the root atoms
(`_NET_CURRENT_DESKTOP`, `_NET_NUMBER_OF_DESKTOPS`,
`_NET_DESKTOP_NAMES`, `_NET_ACTIVE_WINDOW`, `_NET_CLIENT_LIST`) and
per-window props (`_NET_WM_NAME`, `WM_CLASS`, `_NET_WM_DESKTOP`,
`_NET_WM_STATE`, `_NET_WM_WINDOW_TYPE`, `_NET_WM_PID`) and emits one
JSON line²³. Filtering (dock/desktop/notification types,
`SKIP_TASKBAR`) happens in the probe so QML only ever sees task-worthy
windows.

Latency without polling cost: a long-lived
`xprop -root -spy _NET_CURRENT_DESKTOP _NET_ACTIVE_WINDOW
_NET_CLIENT_LIST …` process streams a line per relevant
`PropertyNotify`; QML debounces 60 ms and takes a fresh snapshot.
A 2.5 s timer covers changes that never touch root props (titles).
Cost at idle is effectively zero except the timer snapshot
(~N+1 `xprop` execs for N windows, every 2.5 s — acceptable; a future
python-xlib streaming daemon can replace both parts without changing
the QML API).

### One window per drawer

Replicating upstream's single masked surface on X11 would mean a
full-screen dock window permanently above the desktop — it would
fight xfwm4 focus/stacking and swallow input whenever its shape mask
desyncs. Separate dock windows, sized to their card and created
hidden, are the robust X11 shape. The trade-offs (no outside-click
dismiss, no cross-drawer morph animation, focus on open is a request
the WM may deny) are documented in the README rather than papered
over.

### Flat surfaces for xfwm4's compositor

xfwm4's XRender compositor supports alpha and shadows, not backdrop
blur. Upstream's translucency model (`Colours.layer()` + Hyprland
`blur`+`ignore_alpha` layerrules) would render as a murky tint over
window content here, so `Config.surfaceAlpha/layerAlpha` default to
0.96/0.98 and titlebars are kept opaque. If you switch to picom,
lowering these values plus a `dual_kawase` rule gets you close to
upstream's look (roadmap item).

### CLI probes instead of service plugins

`Sys.qml` deliberately drives `pactl`/`brightnessctl`/`nmcli` and
`/sys`/`/proc` through `sys-state.py` rather than importing the
PipeWire/UPower/NM QML services. That keeps the shell runnable
against a **minimal X11-only Quickshell build** and matches what
xfce4-panel's own plugins do. The price is polling (3 s) and no
per-app volume streams; revert to the D-Bus services here if your
Quickshell build includes them and you want event-driven updates.

### Replacing xfce4-panel safely

`caelestia-xfce-session` kills `xfce4-panel` and `xfce4-notifyd` at
autostart instead of editing xfce4-session's failsafe client list —
no session files are modified, so `uninstall.sh` (or even
`qs kill; xfce4-panel &`) fully restores the stock desktop. The only
persistent tweaks are xfconf values (recorded/undoable) and a
`Hidden=true` user autostart entry masking notifyd.

## Deliberately not ported (and what to use instead)

| Upstream feature | Why not | Use instead |
|---|---|---|
| QML lockscreen (`modules/lock`) | Needs `ext-session-lock-v1` to be *secure*; an X11 dock window can be bypassed/killed | `xflock4` + xfce4-screensaver / light-locker / xscreensaver |
| Live window previews (`windowinfo`, bar popouts) | Screencopy protocol; X11 alternative (XComposite) needs a C++ QML plugin | xfwm4 Alt+Tab preview; icon+title in dashboard |
| Special/scratchpad workspaces | No such concept in xfwm4/EWMH | Extra desktops + `wmctrl` move, or `devilspie2` rules |
| Wallpaper surface + scheme-from-wallpaper | Layer background surface; extraction lives in caelestia-cli plugin | xfdesktop wallpapers; paste/read `scheme.json` for colours |
| Area picker overlay | Screencopy + freeze-frame surface | `xfce4-screenshooter -r` |
| Nexus settings app | Huge, plugin-bound; Xfce already has a settings manager | `xfce4-settings-manager` |
| Weather, audio visualiser (CAVA), lyrics | Extra daemons/libs, untouched by X11 feasibility | Roadmap |

## Roadmap

1. **python-xlib streaming daemon** replacing spy+poll (single
   process, sub-10 ms updates, `_NET_WM_ICON` → PNG cache so tasks
   show real app icons instead of the WM_CLASS heuristic).
2. **DBusMenu for tray** (proper right-click menus via
   `SystemTrayItem.display()`) and a notification history sidebar.
3. **picom profile**: bundled `picom.conf` (dual-kawase blur, corners)
   + lower default surface alpha when picom is detected.
4. **Top-bar variant** (xfce4-panel-style horizontal) behind
   `Config.barEdge`.
5. **Wallpaper → scheme** using `xfconf` xfce4-desktop channel +
   `matugen`/caelestia-cli if installed.
6. **JSON config overlay** reading `~/.config/caelestia/shell.json`
   keys that exist in the X11 model, for users dual-booting setups.
7. Focus reliability: ship the `xdotool windowactivate` fallback
   wrapper as the default launcher keybind command if field testing
   shows dock-focus problems on stock xfwm4 settings.

## References

1. Quickshell X11 panel implementation (EWMH struts, dock type,
   panel stack): <https://deepwiki.com/quickshell-mirror/quickshell/6.4-x11-support-and-panel-system>
2. EWMH spec (`_NET_CLIENT_LIST`, `_NET_CURRENT_DESKTOP`, client
   messages): <https://specifications.freedesktop.org/wm/latest-single/>
3. `wmctrl(1)` — EWMH client-message tool used for all window
   actions: <https://linux.die.net/man/1/wmctrl>
4. Upstream sources consulted for palette/structure:
   `caelestia-dots/shell` (`services/Hypr.qml`, `services/Colours.qml`,
   `modules/bar/Bar.qml`, `modules/Shortcuts.qml`, `shell.qml`) and
   `caelestia-dots/caelestia` (`hypr/scheme/default.lua`, `manifest.toml`).
