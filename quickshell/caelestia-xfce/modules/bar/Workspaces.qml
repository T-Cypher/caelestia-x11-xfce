pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs.services

// Virtual desktops (EWMH _NET_*_DESKTOP), replacing upstream's Hyprland
// workspace strip. Left-click switches; middle-click moves the focused
// window there; scroll cycles desktops (xfwm4 workspace wrapping is
// honoured by wmctrl either way because we compute the target ourselves).
Column {
    id: root

    spacing: 6

    readonly property var modelDesktops: {
        if (Wm.desktops.length > 0)
            return Wm.desktops;
        const fallback = [];
        for (let i = 0; i < Config.barWorkspaceCountFallback; i++)
            fallback.push({
                "index": i,
                "name": String(i + 1),
                "occupied": false,
                "urgent": false
            });
        return fallback;
    }

    Repeater {
        model: root.modelDesktops

        delegate: Rectangle {
            required property var modelData

            readonly property bool isCurrent: modelData.index === Wm.currentDesktop

            width: 38
            height: isCurrent ? 46 : 38
            radius: 13
            color: isCurrent ? Colours.primaryContainer : (modelData.occupied ? Colours.surfaceContainerHigh : "transparent")
            border.width: isCurrent ? 0 : 1
            border.color: Qt.alpha(Colours.outlineVariant, modelData.occupied ? 0 : 0.7)

            Behavior on height {
                NumberAnimation {
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Config.animDuration
                }
            }

            Text {
                anchors.centerIn: parent
                text: Config.barShowDesktopNames ? String(modelData.name).slice(0, 2) : String(modelData.index + 1)
                font.family: Config.fontFamily
                font.pixelSize: 13
                font.weight: parent.isCurrent ? Font.Bold : Font.Medium
                color: parent.isCurrent ? Colours.m3onPrimaryContainer : Colours.m3onSurfaceVariant
            }

            // _NET_WM_STATE_DEMANDS_ATTENTION (e.g. a chat window pinged you)
            Rectangle {
                visible: !!modelData.urgent && !parent.isCurrent
                width: 6
                height: 6
                radius: 3
                color: Colours.error
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 4
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton)
                        Wm.moveActiveToDesktop(modelData.index);
                    else
                        Wm.switchDesktop(modelData.index);
                }
            }

            ToolTip.visible: maHover.hovered
            ToolTip.text: modelData.name
            ToolTip.delay: 600

            HoverHandler {
                id: maHover
            }
        }
    }

    MouseArea {
        width: 38
        height: 14
        onWheel: wheel => Wm.relativeDesktop(wheel.angleDelta.y < 0 ? 1 : -1)

        Rectangle {
            anchors.centerIn: parent
            width: 16
            height: 3
            radius: 2
            color: Qt.alpha(Colours.outlineVariant, 0.8)
        }
    }
}
