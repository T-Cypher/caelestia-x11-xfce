pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services

// Session menu. Upstream drives these with `loginctl`/Hyprland exit;
// on XFCE the correct entry points are xfce4-session itself
// (xfce4-session-logout) and xflock4 for locking — they respect the
// saved session, the configured lock command and shutdown inhibitors.
DrawerWindow {
    id: root

    drawerName: "session"
    drawerWidth: 320

    component SessionButton: Rectangle {
        id: btn

        property string icon: ""
        property string label: ""
        property var command: []
        property bool danger: false
        property bool armed: false

        implicitHeight: 54
        radius: 13
        color: armed ? Colours.errorContainer : (btnMa.containsMouse ? Colours.surfaceContainerHigh : Colours.surfaceContainer)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            MaterialIcon {
                text: btn.icon
                color: btn.armed ? Colours.m3onErrorContainer : (btn.danger ? Colours.error : Colours.primary)
            }
            Text {
                Layout.fillWidth: true
                text: btn.armed ? "Click again to confirm" : btn.label
                font.family: Config.fontFamily
                font.pixelSize: 14
                font.weight: Font.Medium
                color: btn.armed ? Colours.m3onErrorContainer : Colours.m3onSurface
            }
            MaterialIcon {
                text: "chevron_right"
                font.pixelSize: 18
                color: Colours.m3onSurfaceVariant
            }
        }

        MouseArea {
            id: btnMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (btn.danger && !btn.armed) {
                    btn.armed = true;
                    armTimer.restart();
                    return;
                }
                ShellState.closeDrawers();
                Quickshell.execDetached(btn.command);
            }
        }

        Timer {
            id: armTimer
            interval: 2500
            onTriggered: btn.armed = false
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: Sys.userName || "user"
                font.family: Config.fontFamily
                font.pixelSize: 19
                font.weight: Font.Bold
                color: Colours.m3onSurface
            }
            Text {
                text: Sys.hostName + " · Xfce session (X11)"
                font.family: Config.monoFontFamily
                font.pixelSize: 11
                color: Colours.m3onSurfaceVariant
            }
        }

        Item {
            implicitHeight: 4
        }

        SessionButton {
            Layout.fillWidth: true
            icon: "lock"
            label: "Lock screen"
            command: ["xflock4"]
        }
        SessionButton {
            Layout.fillWidth: true
            icon: "bedtime"
            label: "Suspend"
            command: ["xfce4-session-logout", "--suspend"]
        }
        SessionButton {
            Layout.fillWidth: true
            icon: "logout"
            label: "Log out…"
            // No argument = native Xfce logout dialog (with its own
            // confirmation + session-save choice). `--logout` would
            // end the session immediately.
            command: ["xfce4-session-logout"]
        }
        SessionButton {
            Layout.fillWidth: true
            icon: "restart_alt"
            label: "Reboot"
            danger: true
            command: ["xfce4-session-logout", "--reboot"]
        }
        SessionButton {
            Layout.fillWidth: true
            icon: "power_settings_new"
            label: "Shut down"
            danger: true
            command: ["xfce4-session-logout", "--halt"]
        }

        Item {
            Layout.fillHeight: true
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.alpha(Colours.outlineVariant, 0.7)
        }

        SessionButton {
            Layout.fillWidth: true
            icon: "refresh"
            label: "Restart shell"
            command: ["caelestia-xfce-session", "--restart-shell"]
        }
        SessionButton {
            Layout.fillWidth: true
            icon: "tune"
            label: "Xfce settings"
            command: [Config.settingsApp]
        }

        Text {
            Layout.fillWidth: true
            text: "caelestia-xfce · Quickshell on xfwm4/X11"
            font.family: Config.fontFamily
            font.pixelSize: 10
            color: Qt.alpha(Colours.m3onSurfaceVariant, 0.7)
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
