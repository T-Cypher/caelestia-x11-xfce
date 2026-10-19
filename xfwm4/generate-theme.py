#!/usr/bin/env python3
"""Regenerate the Caelestia-Xfce xfwm4 theme pixmaps.

xfwm4 themes are XPM pixmaps + a themerc. Everything here is drawn
programmatically in the stock Caelestia Material-3 scheme colours so
window frames match the Quickshell bar. Run from anywhere:

    python3 generate-theme.py

Output: ./Caelestia-Xfce/xfwm4/  (install.sh copies it to ~/.themes)
"""

import os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   "Caelestia-Xfce", "xfwm4")

# Stock "caelestia" scheme (hypr/scheme/default.lua upstream)
COLORS = {
    ".": None,                # transparent
    "A": "#201f23",           # surfaceContainer — active titlebar
    "I": "#16161a",           # inactive titlebar
    "F": "#131317",           # frame sides (surface)
    "O": "#47464f",           # outlineVariant border
    "G": "#e5e1e7",           # glyph on active
    "g": "#918f9a",           # glyph on inactive (outline)
    "P": "#7171ac",           # pressed bg (primaryContainer)
    "E": "#93000a",           # close pressed bg (errorContainer)
    "W": "#ffffff",
}

TITLE_H = 28
BTN_W = 22
FRM = 4  # frame thickness


def write_xpm(name, rows):
    height = len(rows)
    width = len(rows[0])
    used = []
    for row in rows:
        for ch in row:
            if ch not in used:
                used.append(ch)
    lines = ["/* XPM */", f"static char *xpm[] = {{",
             f'"{width} {height} {len(used)} 1",']
    for ch in used:
        colour = COLORS[ch]
        lines.append(f'"{ch} c {"None" if colour is None else colour}",')
    for i, row in enumerate(rows):
        lines.append(f'"{row}"{"," if i < height - 1 else ""}')
    lines.append("};")
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "w") as fh:
        fh.write("\n".join(lines) + "\n")


def grid(width, height, fill):
    return [[fill] * width for _ in range(height)]


def rows_of(g):
    return ["".join(r) for r in g]


def title_variant(state, bg):
    # title-1/2/4/5 are edge segments, title-3 is the stretched middle.
    specs = {"1": 6, "2": 1, "3": 1, "4": 1, "5": 6}
    for part, width in specs.items():
        g = grid(width, TITLE_H, bg)
        for x in range(width):          # bottom hairline
            g[TITLE_H - 1][x] = "O"
        write_xpm(f"title-{part}-{state}.xpm", rows_of(g))


def frame_pieces(state, bg):
    # Vertical sides: outer outline column + frame fill.
    left = grid(FRM, 1, bg)
    left[0][0] = "O"
    right = grid(FRM, 1, bg)
    right[0][FRM - 1] = "O"
    write_xpm(f"left-{state}.xpm", rows_of(left))
    write_xpm(f"right-{state}.xpm", rows_of(right))

    bottom = grid(1, FRM, bg)
    bottom[FRM - 1][0] = "O"
    write_xpm(f"bottom-{state}.xpm", rows_of(bottom))

    # Top corners with a gently rounded transparent corner (visible
    # only with the xfwm4 compositor enabled).
    tl = grid(FRM + 2, TITLE_H, bg)
    for x in range(FRM + 2):
        tl[TITLE_H - 1][x] = "O"
        tl[1][x] = bg
    tl[0] = [".", ".", ".", bg, bg, bg]
    tl[1] = [".", bg, bg, bg, bg, bg]
    for y in range(TITLE_H):
        tl[y][0] = "O" if tl[y][0] != "." else "."
    write_xpm(f"top-left-{state}.xpm", rows_of(tl))

    tr = [list(reversed(r)) for r in tl]
    write_xpm(f"top-right-{state}.xpm", rows_of(tr))

    bl = grid(FRM, FRM, bg)
    bl[FRM - 1] = [".", "O", "O", "O"]
    for y in range(FRM):
        bl[y][0] = "O" if bl[y][0] != "." else "."
    write_xpm(f"bottom-left-{state}.xpm", rows_of(bl))

    br = [list(reversed(r)) for r in bl]
    write_xpm(f"bottom-right-{state}.xpm", rows_of(br))


def draw_glyph(g, kind, ch):
    cx, cy = BTN_W // 2, TITLE_H // 2
    def px(x, y):
        if 0 <= y < len(g) and 0 <= x < len(g[0]):
            g[y][x] = ch
    if kind == "close":
        for i in range(9):
            x = cx - 5 + i
            for y in (cy - 5 + i, cy + 3 - i):
                for dy in (0, 1):
                    for dx in (0, 1):
                        px(x + dx, y + dy)
    elif kind == "hide":
        for x in range(cx - 5, cx + 5):
            px(x, cy - 1)
            px(x, cy)
    elif kind == "maximize":
        for d in range(-4, 5):
            for t in (0, 1):
                px(cx + d, cy - 4 + t)
                px(cx + d, cy + 3 + t)
                px(cx - 4 + t, cy + d if d < 4 else cy + 3)
                px(cx + 3 + t, cy + d if d < 4 else cy + 3)
    elif kind == "restore":
        for d in range(-3, 3):
            px(cx + d - 2, cy - 1)
            px(cx + d - 2, cy + 4)
            px(cx + d + 1, cy - 4)
            px(cx + d + 1, cy + 1)
        for d in range(-1, 5):
            px(cx - 5, cy + d)
            px(cx, cy + d)
        for d in range(-4, 2):
            px(cx - 2, cy + d)
            px(cx + 3, cy + d)
    elif kind == "menu":
        for dy in (-3, 2):
            for dx in (-3, 2):
                for yy in range(2):
                    for xx in range(2):
                        px(cx + dx + xx - 1, cy + dy + yy - 1)


def buttons():
    kinds = ["close", "hide", "maximize", "menu"]
    for kind in kinds:
        for state, bg, glyph in (("active", "A", "G"),
                                 ("inactive", "I", "g")):
            g = grid(BTN_W, TITLE_H, bg)
            for x in range(BTN_W):
                g[TITLE_H - 1][x] = "O"
            draw_glyph(g, kind, glyph)
            write_xpm(f"{kind}-{state}.xpm", rows_of(g))
        g = grid(BTN_W, TITLE_H, "E" if kind == "close" else "P")
        draw_glyph(g, kind, "W")
        write_xpm(f"{kind}-pressed.xpm", rows_of(g))
    # Maximised (restore) state
    for state, bg, glyph in (("active", "A", "G"), ("inactive", "I", "g")):
        g = grid(BTN_W, TITLE_H, bg)
        for x in range(BTN_W):
            g[TITLE_H - 1][x] = "O"
        draw_glyph(g, "restore", glyph)
        write_xpm(f"maximize-toggled-{state}.xpm", rows_of(g))
    g = grid(BTN_W, TITLE_H, "P")
    draw_glyph(g, "restore", "W")
    write_xpm("maximize-toggled-pressed.xpm", rows_of(g))


THEmerc = """# Caelestia-Xfce — xfwm4 theme matching the caelestia-xfce Quickshell shell.
# Stock Caelestia Material-3 scheme colours; regenerate with ../generate-theme.py
active_text_color=#e5e1e7
inactive_text_color=#918f9a
active_dark_color=#131317
active_mid_color=#201f23
active_light_color=#47464f
inactive_dark_color=#0e0e12
inactive_mid_color=#16161a
inactive_light_color=#39393d
title_shadow_active=false
title_shadow_inactive=false
full_width_title=true
title_vertical_offset_active=1
title_vertical_offset_inactive=1
title_horizontal_offset=6
button_offset=6
button_spacing=4
"""


def main():
    for state, bg in (("active", "A"), ("inactive", "I")):
        title_variant(state, bg)
        frame_pieces(state, "F" if state == "inactive" else bg)
    buttons()
    with open(os.path.join(OUT, "themerc"), "w") as fh:
        fh.write(THEmerc)
    print(f"wrote {len(os.listdir(OUT))} files to {OUT}")


if __name__ == "__main__":
    main()
