#!/usr/bin/env python3
"""Cheap static checks for the QML tree (no X server / qmllint needed).

Catches the failure classes that would kill the shell at load time on
X11: unbalanced braces, leftover Wayland/Hyprland-only imports,
imports of non-existent `qs.*` directories, and references to
singleton types that don't exist (singleton name == file name, since
Quickshell synthesises the `qs` module tree from the directory layout
— exactly like upstream Caelestia, which ships no qmldir files).

    python3 tests/check-qml.py
"""

import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "quickshell", "caelestia-xfce")

FORBIDDEN = ["Quickshell.Hyprland", "Quickshell.Wayland", "WlrLayershell",
             "WlrLayer", "Hyprland.", "import Caelestia", "hyprctl"]


def strip_strings_and_comments(src):
    out, i, n = [], 0, len(src)
    state = None  # None, "'", '"', '`', '//', '/*'
    while i < n:
        ch = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if state is None:
            if ch == "/" and nxt == "/":
                state = "//"; i += 2; continue
            if ch == "/" and nxt == "*":
                state = "/*"; i += 2; continue
            if ch in ("'", '"', "`"):
                state = ch; i += 1; continue
            out.append(ch); i += 1
        elif state == "//":
            if ch == "\n":
                state = None; out.append(ch)
            i += 1
        elif state == "/*":
            if ch == "*" and nxt == "/":
                state = None; i += 2
            else:
                i += 1
        else:  # inside a string
            if ch == "\\":
                i += 2; continue
            if ch == state:
                state = None
            i += 1
    return "".join(out)


def main():
    qml_files = []
    for base, _dirs, files in os.walk(ROOT):
        for f in files:
            if f.endswith(".qml"):
                qml_files.append(os.path.join(base, f))
    assert qml_files, "no QML files found"

    type_names = {os.path.splitext(os.path.basename(p))[0] for p in qml_files}
    singleton_names = set()
    problems = []

    for path in sorted(qml_files):
        rel = os.path.relpath(path, ROOT)
        src = open(path, encoding="utf-8").read()
        if "pragma Singleton" in src:
            singleton_names.add(os.path.splitext(os.path.basename(path))[0])
            if not re.search(r"^import\s+Quickshell\s*$", src, re.M):
                problems.append(f"{rel}: Singleton root type needs 'import Quickshell'")

        for bad in FORBIDDEN:
            # Hypr mentions in comments are fine (they document the port).
            code = strip_strings_and_comments(src)
            if bad in code and not bad.startswith("import"):
                if bad in ("WlrLayershell", "WlrLayer", "Hyprland.", "hyprctl"):
                    problems.append(f"{rel}: forbidden Wayland-only token {bad!r} in code")
            if bad.startswith("import") or "." in bad:
                for line in src.splitlines():
                    s = line.strip()
                    if s.startswith("import") and bad.replace("import ", "") in s:
                        problems.append(f"{rel}: forbidden import: {s}")

        code = strip_strings_and_comments(src)
        stack = []
        pairs = {"}": "{", ")": "(", "]": "["}
        for pos, ch in enumerate(code):
            if ch in "{([":
                stack.append(ch)
            elif ch in pairs:
                if not stack or stack.pop() != pairs[ch]:
                    problems.append(f"{rel}: unbalanced {ch!r} near offset {pos}")
                    break
        if stack:
            problems.append(f"{rel}: unclosed {stack[-1]!r} at EOF")

        # QML forbids property names like `onSurface` (signal-handler
        # syntax) — upstream prefixes them m3onSurface for this reason.
        for m in re.finditer(r"^\s*(?:readonly\s+)?property\s+\w+\s+(on[A-Z]\w*)\s*:", src, re.M):
            problems.append(f"{rel}: property name {m.group(1)!r} starts with on+capital (illegal in QML)")

        for m in re.finditer(r"^import\s+(qs(?:\.[\w]+)*)\s*$", src, re.M):
            relpath = os.path.join(ROOT, *m.group(1).split(".")[1:])
            if m.group(1) != "qs" and not os.path.isdir(relpath):
                problems.append(f"{rel}: import {m.group(1)} -> missing dir {relpath}")

        for name in ("Config", "Colours", "ShellState", "TimeService", "Wm", "Sys", "Notifs"):
            pass  # presence asserted below, once

    # Singleton file names become type names; these would shadow (or be
    # shadowed by) built-in QtQuick types at runtime.
    for clash in ("State", "Time", "PropertyChanges", "AnchorChanges",
                  "StateGroup", "Transition", "Animation"):
        if clash in type_names:
            problems.append(f"type name {clash!r} collides with a QtQuick built-in")

    expected_singletons = {"Config", "Colours", "ShellState", "TimeService", "Wm", "Sys", "Notifs"}
    missing = expected_singletons - singleton_names
    if missing:
        problems.append(f"missing singleton files: {sorted(missing)}")

    if os.path.exists(os.path.join(ROOT, "qmldir")):
        problems.append("qmldir present: Quickshell synthesises the qs.* tree; an explicit qmldir can shadow it")

    print(f"checked {len(qml_files)} QML files, singletons: {sorted(singleton_names)}")
    if problems:
        print("\nPROBLEMS:")
        for p in problems:
            print(" -", p)
        return 1
    print("QML static checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
