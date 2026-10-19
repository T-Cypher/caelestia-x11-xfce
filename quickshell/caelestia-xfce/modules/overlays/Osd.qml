import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services

// Volume / brightness OSD pill, bottom-centre.
PanelWindow {
    id: root

    visible: ShellState.osdVisible
    color: "transparent"
    aboveWindows: true
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: -1

    anchors.bottom: true
    margins.bottom: 34
    implicitWidth: 330
    implicitHeight: 52

    Rectangle {
        anchors.fill: parent
        radius: 26
        color: Colours.drawerBg
        border.width: 1
        border.color: Qt.alpha(Colours.outlineVariant, 0.6)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            MaterialIcon {
                text: ShellState.osdIcon
                color: Colours.primary
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: Colours.surfaceContainerHighest

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, ShellState.osdValue))
                    height: parent.height
                    radius: 4
                    color: Colours.primary

                    Behavior on width {
                        NumberAnimation {
                            duration: 90
                        }
                    }
                }
            }

            Text {
                Layout.preferredWidth: 40
                text: Math.round(ShellState.osdValue * 100) + "%"
                font.family: Config.monoFontFamily
                font.pixelSize: 12
                color: Colours.m3onSurface
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
