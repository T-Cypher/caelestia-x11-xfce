pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services

// App launcher. App data comes from Quickshell's DesktopEntries (freedesktop
// .desktop files) — identical on X11 and Wayland, so this is a straight
// port of upstream modules/launcher, minus the Caelestia C++ fuzzy sorter
// and scheme/wallpaper action plugins (those need the caelestia plugin lib).
DrawerWindow {
    id: root

    drawerName: "launcher"
    drawerWidth: 430

    onDrawerOpenChanged: {
        if (drawerOpen) {
            search.text = "";
            appList.currentIndex = 0;
            Qt.callLater(() => search.forceActiveFocus());
        }
    }

    function launch(entry) {
        if (!entry)
            return;
        if (typeof entry.execute === "function")
            entry.execute();
        else
            Quickshell.execDetached(["gtk-launch", entry.id]);
        ShellState.closeDrawers();
    }

    readonly property var filteredApps: {
        const q = search.text.trim().toLowerCase();
        const all = DesktopEntries.applications.values.filter(e => e && e.name && !e.noDisplay);
        if (q.length === 0)
            return all.slice().sort((a, b) => a.name.localeCompare(b.name)).slice(0, 60);
        const scored = [];
        for (const e of all) {
            const name = (e.name || "").toLowerCase();
            const generic = (e.genericName || "").toLowerCase();
            const comment = (e.comment || "").toLowerCase();
            const idStr = (e.id || "").toLowerCase();
            let score = -1;
            if (name.startsWith(q))
                score = 0;
            else if (name.indexOf(q) !== -1)
                score = 1;
            else if (generic.indexOf(q) !== -1 || idStr.indexOf(q) !== -1)
                score = 2;
            else if (comment.indexOf(q) !== -1)
                score = 3;
            if (score >= 0)
                scored.push({
                    "entry": e,
                    "score": score
                });
        }
        scored.sort((a, b) => (a.score - b.score) || a.entry.name.localeCompare(b.entry.name));
        return scored.slice(0, 60).map(s => s.entry);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 48
            radius: 14
            color: Colours.surfaceContainerHigh

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                MaterialIcon {
                    text: "search"
                    color: Colours.primary
                }

                TextInput {
                    id: search
                    Layout.fillWidth: true
                    color: Colours.m3onSurface
                    font.family: Config.fontFamily
                    font.pixelSize: 15
                    clip: true
                    onAccepted: {
                        const item = root.filteredApps[Math.max(appList.currentIndex, 0)];
                        root.launch(item);
                    }
                    Keys.onEscapePressed: ShellState.closeDrawers()
                    Keys.onDownPressed: appList.incrementCurrentIndex()
                    Keys.onUpPressed: appList.decrementCurrentIndex()

                    Text {
                        visible: search.text.length === 0
                        text: "Search applications…"
                        color: Colours.m3onSurfaceVariant
                        font: search.font
                    }
                }

                MaterialIcon {
                    visible: search.text.length > 0
                    text: "close"
                    font.pixelSize: 18

                    MouseArea {
                        anchors.fill: parent
                        onClicked: search.text = ""
                    }
                }
            }
        }

        // Quick actions (also reachable from the dashboard)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    {
                        "icon": "terminal",
                        "label": "Terminal",
                        "cmd": [Config.terminal]
                    },
                    {
                        "icon": "folder",
                        "label": "Files",
                        "cmd": [Config.fileManager]
                    },
                    {
                        "icon": "language",
                        "label": "Browser",
                        "cmd": [Config.browser]
                    },
                    {
                        "icon": "settings",
                        "label": "Settings",
                        "cmd": [Config.settingsApp]
                    },
                    {
                        "icon": "screenshot_region",
                        "label": "Capture",
                        "cmd": ["xfce4-screenshooter", "-r"]
                    }
                ]

                delegate: Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: 12
                    color: qaMa.containsMouse ? Colours.surfaceContainerHighest : Colours.surfaceContainer

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

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
                        id: qaMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(modelData.cmd);
                            ShellState.closeDrawers();
                        }
                    }
                }
            }
        }

        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: root.filteredApps
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property var modelData
                required property int index

                width: appList.width
                implicitHeight: 54
                radius: 12
                color: index === appList.currentIndex ? Colours.secondaryContainer : (rowMa.containsMouse ? Colours.surfaceContainerHigh : "transparent")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 12

                    Image {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        sourceSize.width: 60
                        sourceSize.height: 60
                        fillMode: Image.PreserveAspectFit
                        source: modelData.icon ? Quickshell.iconPath(modelData.icon, "application-x-executable") : ""
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: modelData.name || ""
                            elide: Text.ElideRight
                            font.family: Config.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Colours.m3onSurface
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: modelData.genericName || modelData.comment || ""
                            elide: Text.ElideRight
                            font.family: Config.fontFamily
                            font.pixelSize: 11
                            color: Colours.m3onSurfaceVariant
                        }
                    }

                    MaterialIcon {
                        visible: index === appList.currentIndex
                        text: "keyboard_return"
                        font.pixelSize: 16
                        color: Colours.m3onSecondaryContainer
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: appList.currentIndex = index
                    onClicked: root.launch(modelData)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: appList.count === 0
                text: "No matching applications"
                font.family: Config.fontFamily
                font.pixelSize: 13
                color: Colours.m3onSurfaceVariant
            }
        }

        Text {
            Layout.fillWidth: true
            text: "↵ launch · ↑↓ navigate · Esc close"
            font.family: Config.fontFamily
            font.pixelSize: 10
            color: Qt.alpha(Colours.m3onSurfaceVariant, 0.7)
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
