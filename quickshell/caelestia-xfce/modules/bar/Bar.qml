pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services
// Workspaces / TaskList / Tray are sibling types in this directory and
// are available without an import (avoids importing our own module).

// The left-edge bar. On X11, PanelWindow becomes an XPanelWindow:
// _NET_WM_WINDOW_TYPE_DOCK + _NET_WM_STRUT_PARTIAL, so xfwm4 shrinks
// the work area exactly like it did for xfce4-panel. One bar is created
// per QScreen (see shell.qml Variants); unlike Hyprland, desktops are
// global across Xinerama screens in xfwm4, so every bar shows the
// same desktop/window state.
PanelWindow {
    id: root

    color: "transparent"
    aboveWindows: true
    focusable: false

    anchors.left: true
    anchors.top: true
    anchors.bottom: true
    implicitWidth: Config.barWidth
    exclusiveZone: Config.barWidth
    exclusionMode: ExclusionMode.Normal

    Rectangle {
        anchors.fill: parent
        color: Colours.barBg

        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: Qt.alpha(Colours.outlineVariant, 0.5)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 8

        // Launcher (upstream: OS logo at the top of the bar)
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            icon: "apps"
            tooltip: "Launcher (Super+Space)"
            active: ShellState.openDrawer === "launcher"
            iconColor: Colours.primary
            onClicked: ShellState.toggleDrawer("launcher")
        }

        Workspaces {
            Layout.alignment: Qt.AlignHCenter
        }

        TaskList {
            Layout.alignment: Qt.AlignHCenter
        }

        Item {
            Layout.fillHeight: true
        }

        Tray {
            Layout.alignment: Qt.AlignHCenter
        }

        // Volume (scroll = adjust, click = mute)
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            icon: Sys.volumeIcon
            tooltip: Sys.volume >= 0 ? ("Volume " + Math.round(Sys.volume * 100) + "%" + (Sys.muted ? " (muted)" : "")) : "Volume"
            onClicked: Sys.toggleMute()
            onWheeled: wheel => Sys.changeVolume(wheel.angleDelta.y > 0 ? Config.volumeStep : -Config.volumeStep)
        }

        // Network
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            icon: Sys.networkIcon
            tooltip: Sys.networkType === "none" ? "Offline" : (Sys.networkName || Sys.networkType)
            onClicked: Quickshell.execDetached(["nm-connection-editor"])
        }

        // Battery (hidden on desktops)
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            visible: Sys.batteryPresent
            icon: Sys.batteryIcon
            iconColor: Sys.batteryPercent <= 15 && !Sys.batteryCharging ? Colours.error : Colours.m3onSurfaceVariant
            tooltip: "Battery " + Sys.batteryPercent + "%" + (Sys.batteryCharging ? " (charging)" : "")
            onClicked: Quickshell.execDetached(["xfce4-power-manager-settings"])
        }

        // Keyboard layout / caps (upstream gets this from Hyprland
        // devices; here setxkbmap + xset via sys-state.py)
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            visible: Sys.kbLayout.length > 0 || Sys.capsLock
            implicitWidth: 38
            implicitHeight: kbCol.implicitHeight + 8
            radius: 10
            color: Sys.capsLock ? Colours.errorContainer : "transparent"

            Column {
                id: kbCol
                anchors.centerIn: parent
                spacing: 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Sys.kbLayout.length > 0
                    text: Sys.kbLayout
                    font.family: Config.monoFontFamily
                    font.pixelSize: 10
                    color: Colours.m3onSurfaceVariant
                }
                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Sys.capsLock
                    text: "keyboard_capslock"
                    font.pixelSize: 16
                    color: Colours.m3onErrorContainer
                }
            }
        }

        // Clock — upstream Caelestia stacks hh / mm in a tertiary pill.
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 42
            implicitHeight: clockCol.implicitHeight + 14
            radius: 14
            color: ShellState.openDrawer === "dashboard" ? Colours.tertiaryContainer : Colours.surfaceContainer

            Column {
                id: clockCol
                anchors.centerIn: parent
                spacing: -2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: TimeService.format("hh")
                    font.family: Config.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: Colours.tertiary
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: TimeService.format("mm")
                    font.family: Config.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: Colours.tertiary
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: TimeService.format("ddd")
                    font.family: Config.fontFamily
                    font.pixelSize: 9
                    color: Colours.m3onSurfaceVariant
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.toggleDrawer("dashboard")
            }
        }

        // Session / power (bottom, like upstream)
        IconButton {
            Layout.alignment: Qt.AlignHCenter
            icon: "power_settings_new"
            tooltip: "Session"
            active: ShellState.openDrawer === "session"
            onClicked: ShellState.toggleDrawer("session")
        }
    }
}
