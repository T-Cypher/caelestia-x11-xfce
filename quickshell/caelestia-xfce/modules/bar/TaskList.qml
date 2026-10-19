pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import qs.services

// Window buttons for the current desktop + pinned launchers — the job
// xfce4-panel's tasklist + launcher plugins did. Upstream Caelestia
// renders window icons *inside* the workspace pills via Hyprland
// toplevels; with EWMH we only get WM_CLASS, so the icon comes from the
// icon theme (Quickshell.iconPath) with a letter fallback. There are no
// live window thumbnails: X11 _NET_WM_ICON is a static pixmap and
// xfwm4 exposes no screencopy protocol.
Column {
    id: root

    spacing: 6
    visible: Config.barShowTaskList

    readonly property var entries: {
        const result = [];
        const seenClasses = [];
        const wins = Wm.windowsOnDesktop(Wm.currentDesktop);
        for (const w of wins) {
            result.push({
                "kind": "window",
                "windowId": w.id,
                "label": w.title || w.wmClass,
                "iconName": (w.wmClass || "").toLowerCase(),
                "active": w.id === Wm.activeWindowId,
                "minimized": !!w.minimized,
                "letter": (w.wmClass || w.title || "?").charAt(0).toUpperCase()
            });
            seenClasses.push((w.wmClass || "").toLowerCase());
        }
        for (const pinnedId of Config.pinnedApps) {
            const entry = DesktopEntries.byId(pinnedId);
            if (!entry)
                continue;
            const running = seenClasses.some(c => c.length > 0 && (c === pinnedId || pinnedId.toLowerCase().indexOf(c) !== -1));
            if (!running) {
                result.push({
                    "kind": "pinned",
                    "entryId": pinnedId,
                    "label": entry.name || pinnedId,
                    "iconName": entry.icon || pinnedId,
                    "active": false,
                    "minimized": false,
                    "letter": (entry.name || pinnedId).charAt(0).toUpperCase()
                });
            }
        }
        return result;
    }

    Rectangle {
        visible: root.entries.length > 0
        width: 24
        height: 1
        anchors.horizontalCenter: parent.horizontalCenter
        color: Qt.alpha(Colours.outlineVariant, 0.8)
    }

    Repeater {
        model: root.entries

        delegate: Rectangle {
            required property var modelData

            width: 40
            height: 40
            radius: 13
            opacity: modelData.minimized ? 0.5 : 1
            color: modelData.active ? Colours.secondaryContainer : (hover.containsMouse ? Colours.surfaceContainerHigh : "transparent")

            Image {
                id: iconImg
                anchors.centerIn: parent
                width: 23
                height: 23
                sourceSize.width: 46
                sourceSize.height: 46
                fillMode: Image.PreserveAspectFit
                source: modelData.iconName ? Quickshell.iconPath(modelData.iconName, true) : ""
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: !iconImg.visible
                text: modelData.letter
                font.family: Config.fontFamily
                font.pixelSize: 16
                font.weight: Font.Bold
                color: modelData.active ? Colours.m3onSecondaryContainer : Colours.primary
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (modelData.kind === "window") {
                        if (mouse.button === Qt.RightButton || mouse.button === Qt.MiddleButton)
                            Wm.closeWindow(modelData.windowId);
                        else
                            Wm.toggleWindow(modelData.windowId);
                    } else if (mouse.button === Qt.LeftButton) {
                        Quickshell.execDetached(["gtk-launch", modelData.entryId]);
                    }
                }
            }

            ToolTip.visible: hover.containsMouse
            ToolTip.text: modelData.label + (modelData.kind === "window" ? "\nRight-click: close" : "")
            ToolTip.delay: 600
        }
    }
}
