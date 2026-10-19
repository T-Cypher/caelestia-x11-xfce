pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Services.SystemTray
import qs.services

// StatusNotifier (SNI) tray. D-Bus based, so identical on X11 and
// Wayland — this is one of the few upstream modules that ports 1:1.
// Note: legacy XEmbed tray icons (very old apps) are X11-only and are
// NOT shown here; xfce4-panel's systray used to bridge them. Modern
// GTK3/Qt5+ apps all speak SNI. See README "Known gaps".
Column {
    id: root

    spacing: 4
    visible: Config.barShowTray && SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        delegate: Item {
            required property SystemTrayItem modelData

            width: 34
            height: 34

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: ma.containsMouse ? Colours.surfaceContainerHigh : "transparent"
            }

            Image {
                anchors.centerIn: parent
                width: 19
                height: 19
                sourceSize.width: 38
                sourceSize.height: 38
                fillMode: Image.PreserveAspectFit
                source: modelData.icon
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton)
                        modelData.activate();
                    else if (mouse.button === Qt.MiddleButton)
                        modelData.secondaryActivate();
                    else
                        modelData.secondaryActivate(); // most SNI items open their menu on secondary activate
                }
                onWheel: wheel => modelData.scroll(wheel.angleDelta.y, false)
            }

            ToolTip.visible: ma.containsMouse && (modelData.tooltipTitle || modelData.title)
            ToolTip.text: modelData.tooltipTitle || modelData.title || ""
            ToolTip.delay: 600
        }
    }
}
