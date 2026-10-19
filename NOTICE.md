# Attribution & licence

`caelestia-xfce` is an independent, unofficial port *inspired by* the
Caelestia dotfiles ecosystem:

- Dotfiles: <https://github.com/caelestia-dots/caelestia>
- Quickshell shell: <https://github.com/caelestia-dots/shell>
- CLI: <https://github.com/caelestia-dots/cli>

What was carried over from upstream:

- the stock `caelestia` Material-3 colour scheme values
  (`hypr/scheme/default.lua` in the dotfiles), used as the default
  palette in `services/Colours.qml` and in the xfwm4 theme;
- the overall shell design language: left vertical bar, drawers
  (launcher / dashboard / session), notification popups, OSD pill,
  Material Symbols iconography, Rubik typography;
- configuration names/semantics where an X11 equivalent exists.

Everything else — the EWMH window-management backend (`Wm.qml`,
`ewmh-state.py`), the per-drawer X11 window model, the Xfce session
integration, the xfwm4 theme and the installers — is original code
written for this port, because the upstream shell is built on
Hyprland IPC and Wayland protocols that do not exist under xfwm4.

Licence: GNU GPL v3 (see `LICENSE`), matching upstream. This project
is not affiliated with or endorsed by the Caelestia contributors.
Please don't file X11/Xfce issues upstream — they target Hyprland.
