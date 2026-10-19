import QtQuick
import QtQuick.Controls
import qs.services
// MaterialIcon is a sibling type in this directory (implicit import).

Rectangle {
    id: root

    property string icon: ""
    property string tooltip: ""
    property bool active: false
    property color iconColor: active ? Colours.m3onPrimaryContainer : Colours.m3onSurfaceVariant
    signal clicked(var mouse)
    signal wheeled(var wheel)

    implicitWidth: 40
    implicitHeight: 40
    radius: 13
    color: active ? Colours.primaryContainer : (ma.containsMouse ? Colours.surfaceContainerHigh : "transparent")

    Behavior on color {
        ColorAnimation {
            duration: Config.animDuration
        }
    }

    MaterialIcon {
        anchors.centerIn: parent
        text: root.icon
        color: root.iconColor
        fillGrade: root.active ? 1 : 0
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => root.wheeled(wheel)
    }

    ToolTip.visible: tooltip.length > 0 && ma.containsMouse
    ToolTip.text: tooltip
    ToolTip.delay: 600
}
