pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services

// Top-right notification popups. Dock-typed, no strut, never steals
// focus (focusable: false). Height hugs the list so the window does not
// swallow clicks over the desktop below it.
PanelWindow {
    id: root

    visible: Notifs.list.length > 0
    color: "transparent"
    aboveWindows: true
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: -1

    anchors.top: true
    anchors.right: true
    margins.top: 10
    margins.right: 10
    implicitWidth: 368
    implicitHeight: Math.max(listCol.implicitHeight, 1)

    Column {
        id: listCol
        width: parent.width
        spacing: 8

        Repeater {
            model: Notifs.list

            delegate: Rectangle {
                required property var modelData

                width: listCol.width
                implicitHeight: cardLayout.implicitHeight + 20
                radius: 14
                color: Colours.drawerBg
                border.width: 1
                border.color: Qt.alpha(Colours.outlineVariant, 0.6)

                ColumnLayout {
                    id: cardLayout
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Image {
                            id: notifIcon
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            sourceSize.width: 64
                            sourceSize.height: 64
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                            source: {
                                if (modelData.image && String(modelData.image).length > 0)
                                    return modelData.image;
                                if (modelData.appIcon && String(modelData.appIcon).length > 0)
                                    return Quickshell.iconPath(String(modelData.appIcon), true);
                                return "";
                            }
                        }

                        MaterialIcon {
                            visible: !notifIcon.visible
                            text: "notifications"
                            color: Colours.primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: modelData.summary || modelData.appName || "Notification"
                                elide: Text.ElideRight
                                font.family: Config.fontFamily
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: Colours.m3onSurface
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: modelData.body || ""
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                font.family: Config.fontFamily
                                font.pixelSize: 12
                                color: Colours.m3onSurfaceVariant
                            }
                            Text {
                                visible: (modelData.appName || "").length > 0
                                text: modelData.appName
                                font.family: Config.fontFamily
                                font.pixelSize: 10
                                color: Qt.alpha(Colours.m3onSurfaceVariant, 0.75)
                            }
                        }

                        MaterialIcon {
                            text: "close"
                            font.pixelSize: 17
                            color: Colours.m3onSurfaceVariant

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.dismiss()
                            }
                        }
                    }

                    // Notification actions (org.freedesktop.Notifications)
                    RowLayout {
                        Layout.fillWidth: true
                        visible: modelData.actions && modelData.actions.length > 0
                        spacing: 6

                        Repeater {
                            model: modelData.actions

                            delegate: Rectangle {
                                required property var modelData

                                implicitWidth: actionText.implicitWidth + 20
                                implicitHeight: 28
                                radius: 9
                                color: actionMa.containsMouse ? Colours.primaryContainer : Colours.surfaceContainerHigh

                                Text {
                                    id: actionText
                                    anchors.centerIn: parent
                                    text: modelData.text || ""
                                    font.family: Config.fontFamily
                                    font.pixelSize: 11
                                    color: Colours.m3onSurface
                                }

                                MouseArea {
                                    id: actionMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.invoke()
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: modelData.dismiss()
                }
            }
        }
    }
}
