pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.components
import qs.services

// Dashboard: clock/date, MPRIS media, volume/brightness, system load and
// quick toggles. Weather/visualiser cards from upstream are out of MVP
// scope (see PORTING.md); Mpris is D-Bus, so it behaves identically on X11.
DrawerWindow {
    id: root

    drawerName: "dashboard"
    drawerWidth: 380

    readonly property var player: {
        const players = Mpris.players.values;
        for (const p of players)
            if (p.isPlaying)
                return p;
        return players.length > 0 ? players[0] : null;
    }

    function artistText(p) {
        if (!p)
            return "";
        const a = (p.trackArtists !== undefined && p.trackArtists !== null && String(p.trackArtists).length > 0) ? p.trackArtists : p.trackArtist;
        if (a === undefined || a === null)
            return "";
        if (typeof a === "object" && a.length !== undefined) {
            const parts = [];
            for (let i = 0; i < a.length; i++)
                parts.push(String(a[i]));
            return parts.join(", ");
        }
        return String(a);
    }

    component LevelSlider: RowLayout {
        id: lvl

        property string icon: ""
        property real value: 0       // 0..1 display value
        property bool enabled2: true
        signal moved(real v)
        signal iconClicked

        spacing: 10
        opacity: enabled2 ? 1 : 0.4

        MaterialIcon {
            text: lvl.icon
            color: Colours.primary

            MouseArea {
                anchors.fill: parent
                onClicked: lvl.iconClicked()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 8
            radius: 4
            color: Colours.surfaceContainerHighest

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, lvl.value))
                height: parent.height
                radius: 4
                color: Colours.primary
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                enabled: lvl.enabled2
                onPressed: mouse => lvl.moved(Math.max(0, Math.min(1, mouse.x / width)))
                onPositionChanged: mouse => {
                    if (pressed)
                        lvl.moved(Math.max(0, Math.min(1, mouse.x / width)));
                }
            }
        }

        Text {
            Layout.preferredWidth: 36
            text: Math.round(Math.max(0, Math.min(1, lvl.value)) * 100) + "%"
            font.family: Config.monoFontFamily
            font.pixelSize: 11
            color: Colours.m3onSurfaceVariant
            horizontalAlignment: Text.AlignRight
        }
    }

    component StatBar: ColumnLayout {
        property string label: ""
        property real value: 0    // 0..100

        spacing: 4

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: label
                font.family: Config.fontFamily
                font.pixelSize: 11
                color: Colours.m3onSurfaceVariant
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                text: Math.round(value) + "%"
                font.family: Config.monoFontFamily
                font.pixelSize: 11
                color: Colours.m3onSurfaceVariant
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6
            radius: 3
            color: Colours.surfaceContainerHighest

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, value / 100))
                height: parent.height
                radius: 3
                color: value > 85 ? Colours.error : Colours.tertiary
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        // Header: user@host + big date
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: TimeService.format("dddd")
                font.family: Config.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Colours.tertiary
            }
            Text {
                text: TimeService.format("d MMMM yyyy")
                font.family: Config.fontFamily
                font.pixelSize: 22
                font.weight: Font.Bold
                color: Colours.m3onSurface
            }
            Text {
                text: Sys.userName + "@" + Sys.hostName + " · " + TimeService.format(Config.clockFormat)
                font.family: Config.monoFontFamily
                font.pixelSize: 11
                color: Colours.m3onSurfaceVariant
            }
        }

        // Active window (EWMH; upstream shows a live preview — not possible
        // under xfwm4, see PORTING.md)
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: activeCol.implicitHeight + 20
            radius: 14
            color: Colours.surfaceContainer

            ColumnLayout {
                id: activeCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                SectionLabel {
                    text: "Active window"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: Wm.activeTitle.length > 0 ? Wm.activeTitle : "Desktop"
                        elide: Text.ElideRight
                        font.family: Config.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        color: Colours.m3onSurface
                    }
                    IconButton {
                        visible: !!Wm.activeWindow
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: 9
                        icon: "minimize"
                        tooltip: "Minimize"
                        onClicked: Wm.minimizeWindow(Wm.activeWindowId)
                    }
                    IconButton {
                        visible: !!Wm.activeWindow
                        implicitWidth: 30
                        implicitHeight: 30
                        radius: 9
                        icon: "close"
                        tooltip: "Close window"
                        onClicked: Wm.closeWindow(Wm.activeWindowId)
                    }
                }

                Text {
                    visible: !!Wm.activeWindow
                    text: Wm.activeClass + " · desktop " + (Wm.currentDesktop + 1) + " of " + Math.max(Wm.desktops.length, 1)
                    font.family: Config.monoFontFamily
                    font.pixelSize: 10
                    color: Colours.m3onSurfaceVariant
                }
            }
        }

        // Media
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: mediaCol.implicitHeight + 20
            radius: 14
            color: Colours.surfaceContainer

            ColumnLayout {
                id: mediaCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                SectionLabel {
                    text: "Media"
                }

                Text {
                    Layout.fillWidth: true
                    visible: !root.player
                    text: "No media player"
                    font.family: Config.fontFamily
                    font.pixelSize: 12
                    color: Colours.m3onSurfaceVariant
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: !!root.player
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        text: root.player ? (root.player.trackTitle || "Unknown title") : ""
                        elide: Text.ElideRight
                        font.family: Config.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: Colours.m3onSurface
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.artistText(root.player)
                        elide: Text.ElideRight
                        font.family: Config.fontFamily
                        font.pixelSize: 11
                        color: Colours.m3onSurfaceVariant
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 6

                        IconButton {
                            icon: "skip_previous"
                            onClicked: root.player.previous()
                        }
                        IconButton {
                            icon: root.player && root.player.isPlaying ? "pause" : "play_arrow"
                            active: true
                            onClicked: {
                                if (!root.player)
                                    return;
                                if (root.player.isPlaying)
                                    root.player.pause();
                                else
                                    root.player.play();
                            }
                        }
                        IconButton {
                            icon: "skip_next"
                            onClicked: root.player.next()
                        }
                    }
                }
            }
        }

        // Sliders
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: sliderCol.implicitHeight + 20
            radius: 14
            color: Colours.surfaceContainer

            ColumnLayout {
                id: sliderCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12

                SectionLabel {
                    text: "Sound & light"
                }

                LevelSlider {
                    Layout.fillWidth: true
                    icon: Sys.volumeIcon
                    value: Math.max(Sys.volume, 0)
                    enabled2: Sys.volume >= 0
                    onMoved: v => Sys.setVolume(v)
                    onIconClicked: Sys.toggleMute()
                }
                LevelSlider {
                    Layout.fillWidth: true
                    visible: Sys.brightness >= 0
                    icon: "brightness_medium"
                    value: Math.max(Sys.brightness, 0)
                    onMoved: v => Sys.setBrightness(v)
                }
            }
        }

        // System load
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: sysCol.implicitHeight + 20
            radius: 14
            color: Colours.surfaceContainer

            ColumnLayout {
                id: sysCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                SectionLabel {
                    text: "System"
                }

                StatBar {
                    Layout.fillWidth: true
                    label: "CPU"
                    value: Sys.cpuPercent
                }
                StatBar {
                    Layout.fillWidth: true
                    label: "Memory"
                    value: Sys.memPercent
                }
                Text {
                    visible: Sys.batteryPresent
                    text: "Battery " + Sys.batteryPercent + "%" + (Sys.batteryCharging ? " · charging" : "")
                    font.family: Config.fontFamily
                    font.pixelSize: 11
                    color: Colours.m3onSurfaceVariant
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached(["xfce4-taskmanager"]);
                    ShellState.closeDrawers();
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }

        // Quick actions
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    {
                        "icon": "screenshot_region",
                        "label": "Screenshot",
                        "cmd": ["xfce4-screenshooter", "-r"]
                    },
                    {
                        "icon": "notifications_off",
                        "label": "Clear alerts",
                        "cmd": []
                    },
                    {
                        "icon": "settings",
                        "label": "Settings",
                        "cmd": [Config.settingsApp]
                    },
                    {
                        "icon": "lock",
                        "label": "Lock",
                        "cmd": ["xflock4"]
                    }
                ]

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 56
                    radius: 12
                    color: dashMa.containsMouse ? Colours.surfaceContainerHighest : Colours.surfaceContainer

                    Column {
                        anchors.centerIn: parent
                        spacing: 3

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.icon
                            font.pixelSize: 20
                            color: Colours.secondary
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            font.family: Config.fontFamily
                            font.pixelSize: 9
                            color: Colours.m3onSurfaceVariant
                        }
                    }

                    MouseArea {
                        id: dashMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.label === "Clear alerts")
                                Notifs.dismissAll();
                            else
                                Quickshell.execDetached(modelData.cmd);
                            ShellState.closeDrawers();
                        }
                    }
                }
            }
        }
    }
}
